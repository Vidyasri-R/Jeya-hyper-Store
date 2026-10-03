import { logger } from '../../config/logger';

/**
 * Exact R2 usage from Cloudflare's GraphQL Analytics API — optional. Needs an API token with
 * "Account Analytics: Read" (CLOUDFLARE_API_TOKEN). Without it the monitor falls back to its
 * own counts, which can't see Class B reads (customers' phones loading product images).
 * Class lists from developers.cloudflare.com/r2/pricing; DeleteObject & co. are free.
 */
const ENDPOINT = 'https://api.cloudflare.com/client/v4/graphql';
const CLASS_A = new Set([
  'ListBuckets', 'PutBucket', 'ListObjects', 'PutObject', 'CopyObject', 'CompleteMultipartUpload',
  'CreateMultipartUpload', 'LifecycleStorageTierTransition', 'ListMultipartUploads', 'UploadPart',
  'UploadPartCopy', 'ListParts', 'PutBucketEncryption', 'PutBucketCors', 'PutBucketLifecycleConfiguration',
]);
const FREE = new Set(['DeleteObject', 'DeleteBucket', 'AbortMultipartUpload']);

const QUERY = `query R2Usage($accountTag: string!, $start: Time, $end: Time) {
  viewer {
    accounts(filter: { accountTag: $accountTag }) {
      r2OperationsAdaptiveGroups(limit: 1000, filter: { datetime_geq: $start, datetime_leq: $end }) {
        sum { requests }
        dimensions { actionType }
      }
      r2StorageAdaptiveGroups(limit: 200, filter: { datetime_geq: $start, datetime_leq: $end }, orderBy: [datetime_DESC]) {
        max { objectCount payloadSize metadataSize }
        dimensions { bucketName datetime }
      }
    }
  }
}`;

type Response = {
  data?: {
    viewer?: {
      accounts?: {
        r2OperationsAdaptiveGroups?: { sum: { requests: number }; dimensions: { actionType: string } }[];
        r2StorageAdaptiveGroups?: { max: { objectCount: number; payloadSize: number; metadataSize: number }; dimensions: { bucketName: string; datetime: string } }[];
      }[];
    };
  };
  errors?: { message: string }[] | null;
};

export type R2Usage = { classAOps: number; classBOps: number; storageBytes: number; objectCount: number };

export async function fetchR2Usage(accountId: string, token: string, start: Date, end: Date): Promise<R2Usage | null> {
  try {
    const response = await fetch(ENDPOINT, {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ query: QUERY, variables: { accountTag: accountId, start: start.toISOString(), end: end.toISOString() } }),
      signal: AbortSignal.timeout(15_000),
    });
    const body = (await response.json()) as Response;
    if (!response.ok || body.errors?.length) {
      logger.warn({ status: response.status, errors: body.errors?.map((error) => error.message) }, 'cloudflare analytics query failed');
      return null;
    }
    const account = body.data?.viewer?.accounts?.[0];
    let classAOps = 0;
    let classBOps = 0;
    for (const group of account?.r2OperationsAdaptiveGroups ?? []) {
      const action = group.dimensions.actionType;
      if (FREE.has(action)) continue;
      if (CLASS_A.has(action)) classAOps += group.sum.requests;
      else classBOps += group.sum.requests;
    }
    // Newest sample per bucket (rows are newest first), summed across buckets — the free tier is per account.
    const latest = new Map<string, { bytes: number; objects: number }>();
    for (const group of account?.r2StorageAdaptiveGroups ?? []) {
      if (!latest.has(group.dimensions.bucketName)) {
        latest.set(group.dimensions.bucketName, { bytes: group.max.payloadSize + group.max.metadataSize, objects: group.max.objectCount });
      }
    }
    const storage = [...latest.values()].reduce((sum, bucket) => ({ bytes: sum.bytes + bucket.bytes, objects: sum.objects + bucket.objects }), { bytes: 0, objects: 0 });
    return { classAOps, classBOps, storageBytes: storage.bytes, objectCount: storage.objects };
  } catch (error) {
    logger.warn({ err: error }, 'cloudflare analytics unreachable');
    return null;
  }
}
