import { Upload } from '@aws-sdk/lib-storage';
import type { Readable } from 'node:stream';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  ListObjectsV2Command,
  NotFound,
  PutObjectCommand,
  S3Client,
  type PutObjectCommandInput,
} from '@aws-sdk/client-s3';
import { AppError } from '../common/errors';
import { env } from '../config/env';
import { traffic } from './traffic';

/**
 * Cloudflare R2 via its S3-compatible API.
 *
 * Object keys are content-addressed or versioned by the caller
 * (e.g. products/<itemCode>/<sha1>.webp) so they can be cached forever —
 * never overwrite an existing key with different bytes.
 */
type R2Config = { accountId: string; accessKeyId: string; secretAccessKey: string; bucket: string; publicBaseUrl: string };

function readConfig(): R2Config | null {
  const { R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_PUBLIC_BASE_URL } = env;
  const values = [R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_PUBLIC_BASE_URL];
  if (values.every((value) => value === undefined)) return null;
  if (values.some((value) => value === undefined)) {
    throw new Error(
      'Cloudflare R2 is partially configured: set all of R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_PUBLIC_BASE_URL',
    );
  }
  return {
    accountId: R2_ACCOUNT_ID!,
    accessKeyId: R2_ACCESS_KEY_ID!,
    secretAccessKey: R2_SECRET_ACCESS_KEY!,
    bucket: R2_BUCKET,
    publicBaseUrl: R2_PUBLIC_BASE_URL!,
  };
}

const config = readConfig();

const client = config
  ? new S3Client({
      region: 'auto',
      endpoint: `https://${config.accountId}.r2.cloudflarestorage.com`,
      credentials: { accessKeyId: config.accessKeyId, secretAccessKey: config.secretAccessKey },
      maxAttempts: 3,
      // Fail instead of hanging forever on a stalled connection (the SDK has no timeout by default).
      requestHandler: { connectionTimeout: 5_000, requestTimeout: 60_000 },
      // R2 doesn't support the newer default checksum headers on every operation.
      requestChecksumCalculation: 'WHEN_REQUIRED',
      responseChecksumValidation: 'WHEN_REQUIRED',
    })
  : null;

function requireClient(): { client: S3Client; config: R2Config } {
  if (!client || !config) throw new AppError('UPSTREAM_UNAVAILABLE', 'Image storage is not configured');
  return { client, config };
}

function assertKey(key: string): void {
  if (!/^[a-z0-9][a-z0-9/_.-]{0,500}$/i.test(key) || key.includes('..')) {
    throw new Error(`invalid object key: ${key}`);
  }
}

/** Raw object operations on any bucket the R2 token can reach (backups use a private one). */
function bucketOps(bucket: string) {
  return {
    async put(key: string, body: Buffer, options: { contentType: string; metadata?: Record<string, string> }) {
      assertKey(key);
      await requireClient().client.send(
        new PutObjectCommand({ Bucket: bucket, Key: key, Body: body, ContentType: options.contentType, ...(options.metadata ? { Metadata: options.metadata } : {}) }),
      );
      traffic.countR2({ uploadBytes: body.length, classAOps: 1 });
    },

    async get(key: string): Promise<Buffer> {
      assertKey(key);
      const result = await requireClient().client.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
      return Buffer.from(await result.Body!.transformToByteArray());
    },

    async list(prefix: string): Promise<{ key: string; size: number; lastModified: Date | null }[]> {
      const objects: { key: string; size: number; lastModified: Date | null }[] = [];
      let token: string | undefined;
      do {
        const page = await requireClient().client.send(new ListObjectsV2Command({ Bucket: bucket, Prefix: prefix, ContinuationToken: token }));
        traffic.countR2({ classAOps: 1 });
        for (const object of page.Contents ?? []) {
          if (object.Key) objects.push({ key: object.Key, size: object.Size ?? 0, lastModified: object.LastModified ?? null });
        }
        token = page.IsTruncated ? page.NextContinuationToken : undefined;
      } while (token);
      return objects;
    },
  };
}

export const r2 = {
  /** e.g. r2.bucket(env.R2_BACKUP_BUCKET).put(...) */
  bucket: bucketOps,

  isConfigured: (): boolean => client !== null,

  publicUrl(key: string): string {
    assertKey(key);
    return `${requireClient().config.publicBaseUrl}/${key}`;
  },

  async put(
    key: string,
    body: Buffer,
    options: { contentType: string; cacheControl?: string; metadata?: Record<string, string> },
  ): Promise<{ key: string; url: string; etag: string | undefined }> {
    assertKey(key);
    const { client: s3, config: cfg } = requireClient();
    const input: PutObjectCommandInput = {
      Bucket: cfg.bucket,
      Key: key,
      Body: body,
      ContentType: options.contentType,
      CacheControl: options.cacheControl ?? 'public, max-age=31536000, immutable',
      ...(options.metadata ? { Metadata: options.metadata } : {}),
    };
    const result = await s3.send(new PutObjectCommand(input));
    traffic.countR2({ uploadBytes: body.length, classAOps: 1 });
    return { key, url: `${cfg.publicBaseUrl}/${key}`, etag: result.ETag };
  },

  /**
   * Streams a large file (shop TV videos) in 8 MB parts, so a 100 MB upload never sits in the
   * server's memory. Rejects when the stream ends up larger than [maxBytes].
   */
  async putStream(
    key: string,
    body: Readable,
    options: { contentType: string; maxBytes: number; cacheControl?: string },
  ): Promise<{ key: string; url: string; bytes: number }> {
    assertKey(key);
    const { client: s3, config: cfg } = requireClient();
    let bytes = 0;
    body.on('data', (chunk: Buffer) => {
      bytes += chunk.length;
      if (bytes > options.maxBytes) body.destroy(new Error('too_large'));
    });
    const upload = new Upload({
      client: s3,
      params: { Bucket: cfg.bucket, Key: key, Body: body, ContentType: options.contentType, CacheControl: options.cacheControl ?? 'public, max-age=31536000, immutable' },
      partSize: 8 * 1024 * 1024,
      queueSize: 2,
    });
    await upload.done();
    traffic.countR2({ uploadBytes: bytes, classAOps: Math.max(1, Math.ceil(bytes / (8 * 1024 * 1024)) + 2) });
    return { key, url: `${cfg.publicBaseUrl}/${key}`, bytes };
  },

  async exists(key: string): Promise<boolean> {
    assertKey(key);
    const { client: s3, config: cfg } = requireClient();
    try {
      await s3.send(new HeadObjectCommand({ Bucket: cfg.bucket, Key: key }));
      return true;
    } catch (error) {
      if (error instanceof NotFound || (error as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode === 404) {
        return false;
      }
      throw error;
    }
  },

  /**
   * Total bytes/objects in the bucket (free tier: 10 GB). One Class A op per 1,000 objects,
   * so a daily run over ~30k product images costs ~30 of the 1M free monthly operations.
   */
  async storageStats(prefix?: string): Promise<{ bytes: number; objects: number }> {
    const { client: s3, config: cfg } = requireClient();
    let bytes = 0;
    let objects = 0;
    let token: string | undefined;
    do {
      const page = await s3.send(
        new ListObjectsV2Command({ Bucket: cfg.bucket, ContinuationToken: token, ...(prefix ? { Prefix: prefix } : {}) }),
      );
      traffic.countR2({ classAOps: 1 });
      for (const object of page.Contents ?? []) {
        bytes += object.Size ?? 0;
        objects++;
      }
      token = page.IsTruncated ? page.NextContinuationToken : undefined;
    } while (token);
    return { bytes, objects };
  },

  /** Public URL → object key, or null when the URL isn't in our bucket. */
  keyFromUrl(url: string): string | null {
    if (!config || !url.startsWith(`${config.publicBaseUrl}/`)) return null;
    return url.slice(config.publicBaseUrl.length + 1);
  },

  async remove(key: string): Promise<void> {
    assertKey(key);
    const { client: s3, config: cfg } = requireClient();
    await s3.send(new DeleteObjectCommand({ Bucket: cfg.bucket, Key: key }));
  },
};
