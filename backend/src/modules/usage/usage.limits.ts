import { z } from 'zod';
import { logger } from '../../config/logger';
import { appConfigService, CONFIG_KEYS } from '../app-config/app-config.service';

const GB = 1_000_000_000;
const MB = 1_000_000;
const MiB = 1024 * 1024;

/**
 * The plans this project runs on (October 2026) and what going past them costs.
 * Decimal GB/MB on purpose: slightly smaller than GiB, so alerts fire a little early.
 * Stored in app_config `usage.limits` so they can be corrected from the admin app
 * without a deploy if a provider changes its pricing.
 *
 * Sources: render.com/docs/outbound-bandwidth (Hobby: 5 GB, then $0.15/GB),
 * supabase.com/docs/guides/platform/billing-on-supabase (Free: 500 MB DB, 5 GB egress),
 * developers.cloudflare.com/r2/pricing (10 GB-month, 1M Class A, 10M Class B free).
 */
export const DEFAULT_USAGE_LIMITS = {
  usdToInr: 88,
  render: {
    plan: 'Starter instance on Hobby workspace',
    monthlyUsd: 7,
    memoryBytes: 512 * MiB,
    bandwidthBytes: 5 * GB,
    bandwidthOverageUsdPerGb: 0.15,
    pipelineMinutes: 500,
  },
  supabase: {
    plan: 'Free',
    dbSizeBytes: 500 * MB,
    egressBytes: 5 * GB,
  },
  r2: {
    plan: 'Free tier',
    storageBytes: 10 * GB,
    classAOps: 1_000_000,
    classBOps: 10_000_000,
    storageUsdPerGbMonth: 0.015,
    classAUsdPerMillion: 4.5,
    classBUsdPerMillion: 0.36,
  },
  /** % of a limit (used now, or projected for month end) that raises an alert. */
  thresholds: { warnPercent: 70, criticalPercent: 90, projectedWarnPercent: 100, projectedCriticalPercent: 150 },
};

const positive = z.number().positive();
const limitsSchema = z.object({
  usdToInr: positive.max(1000),
  render: z.object({
    plan: z.string().max(80),
    monthlyUsd: z.number().min(0).max(1000),
    memoryBytes: positive,
    bandwidthBytes: positive,
    bandwidthOverageUsdPerGb: z.number().min(0),
    pipelineMinutes: positive,
  }),
  supabase: z.object({ plan: z.string().max(80), dbSizeBytes: positive, egressBytes: positive }),
  r2: z.object({
    plan: z.string().max(80),
    storageBytes: positive,
    classAOps: positive,
    classBOps: positive,
    storageUsdPerGbMonth: z.number().min(0),
    classAUsdPerMillion: z.number().min(0),
    classBUsdPerMillion: z.number().min(0),
  }),
  thresholds: z.object({
    warnPercent: z.number().min(10).max(100),
    criticalPercent: z.number().min(10).max(100),
    projectedWarnPercent: z.number().min(10).max(1000),
    projectedCriticalPercent: z.number().min(10).max(1000),
  }),
});

export type UsageLimits = z.infer<typeof limitsSchema>;
export const usageLimitsSchema = limitsSchema;

export async function usageLimits(): Promise<UsageLimits> {
  const stored = await appConfigService.getObject(CONFIG_KEYS.USAGE_LIMITS, {} as Record<string, unknown>);
  const merged = {
    ...DEFAULT_USAGE_LIMITS,
    ...stored,
    render: { ...DEFAULT_USAGE_LIMITS.render, ...(stored.render as object | undefined) },
    supabase: { ...DEFAULT_USAGE_LIMITS.supabase, ...(stored.supabase as object | undefined) },
    r2: { ...DEFAULT_USAGE_LIMITS.r2, ...(stored.r2 as object | undefined) },
    thresholds: { ...DEFAULT_USAGE_LIMITS.thresholds, ...(stored.thresholds as object | undefined) },
  };
  const parsed = limitsSchema.safeParse(merged);
  if (parsed.success) return parsed.data;
  logger.error({ issues: parsed.error.issues }, 'invalid usage.limits in app_config — using defaults');
  return DEFAULT_USAGE_LIMITS;
}
