import { env, isProduction } from '../../config/env';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import type { AdminAlert, AlertLevel } from '../../db/schema';
import { fetchR2Usage, type R2Usage } from '../../integrations/cloudflare/analytics';
import { backupService } from '../backup/backup.service';
import { r2 } from '../../infra/r2';
import { traffic } from '../../infra/traffic';
import { notifier } from './notifier';
import { usageLimits, type UsageLimits } from './usage.limits';
import { usageRepository } from './usage.repository';

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const GB = 1_000_000_000;
/** Projections from less than this much of the month are too noisy to alert on. */
const MIN_DAYS_FOR_PROJECTION = 3;
/** Critical alerts are re-sent this often until resolved. */
const CRITICAL_REPEAT_MS = DAY_MS;

type Level = AlertLevel | 'ok';
const RANK: Record<Level, number> = { ok: 0, info: 1, warning: 2, critical: 3 };

export function istDay(at = new Date()): string {
  return new Date(at.getTime() + IST_OFFSET_MS).toISOString().slice(0, 10);
}

function istMonth(now = new Date()) {
  const ist = new Date(now.getTime() + IST_OFFSET_MS);
  const year = ist.getUTCFullYear();
  const month = ist.getUTCMonth();
  const start = new Date(Date.UTC(year, month, 1) - IST_OFFSET_MS);
  const daysInMonth = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  const firstDay = `${year}-${String(month + 1).padStart(2, '0')}-01`;
  const lastDay = `${year}-${String(month + 1).padStart(2, '0')}-${String(daysInMonth).padStart(2, '0')}`;
  return { start, firstDay, lastDay, daysInMonth, daysElapsed: Math.max((now.getTime() - start.getTime()) / DAY_MS, 1 / 24), label: firstDay.slice(0, 7) };
}

export function formatBytes(bytes: number): string {
  if (bytes >= GB) return `${(bytes / GB).toFixed(2)} GB`;
  if (bytes >= 1_000_000) return `${(bytes / 1_000_000).toFixed(1)} MB`;
  if (bytes >= 1_000) return `${Math.round(bytes / 1_000)} KB`;
  return `${bytes} B`;
}

const formatCount = (n: number) => n.toLocaleString('en-IN');
const round2 = (n: number) => Math.round(n * 100) / 100;

export type UsageMetric = {
  id: string;
  label: string;
  unit: 'bytes' | 'count';
  /** null = not measurable with the current setup (see `note`). */
  used: number | null;
  limit: number;
  percent: number | null;
  /** Month-end projection at the current rate (cumulative metrics only). */
  projected: number | null;
  projectedPercent: number | null;
  level: Level;
  note: string;
};

export type ServiceUsage = {
  id: 'render' | 'supabase' | 'r2' | 'razorpay';
  name: string;
  plan: string;
  /** Bill for this month so far / at month end at the current rate, in USD (Razorpay: INR, see costInr). */
  costSoFarUsd: number;
  costProjectedUsd: number;
  costInr: number;
  metrics: UsageMetric[];
  notes: string[];
};

function levelFor(percent: number | null, projectedPercent: number | null, limits: UsageLimits, useProjection: boolean): Level {
  const t = limits.thresholds;
  if (percent === null) return 'ok';
  if (percent >= t.criticalPercent || (useProjection && projectedPercent !== null && projectedPercent >= t.projectedCriticalPercent)) return 'critical';
  if (percent >= t.warnPercent || (useProjection && projectedPercent !== null && projectedPercent >= t.projectedWarnPercent)) return 'warning';
  return 'ok';
}

/** Exported for tests. */
export function buildMetric(
  limits: UsageLimits,
  input: { id: string; label: string; unit: 'bytes' | 'count'; used: number | null; limit: number; cumulative: boolean; daysElapsed: number; daysInMonth: number; note: string },
): UsageMetric {
  const percent = input.used === null ? null : round2((input.used / input.limit) * 100);
  const projected = input.used !== null && input.cumulative && input.daysElapsed >= 1 ? Math.round((input.used / input.daysElapsed) * input.daysInMonth) : null;
  const projectedPercent = projected === null ? null : round2((projected / input.limit) * 100);
  return {
    id: input.id,
    label: input.label,
    unit: input.unit,
    used: input.used,
    limit: input.limit,
    percent,
    projected,
    projectedPercent,
    level: levelFor(percent, projectedPercent, limits, input.cumulative && input.daysElapsed >= MIN_DAYS_FOR_PROJECTION),
    note: input.note,
  };
}

let cfR2: { at: number; usage: R2Usage } | null = null;
let alertSummaryCache: { at: number; value: { open: number; worst: AlertLevel | null } } | null = null;

function describe(m: UsageMetric): string {
  const fmt = (n: number) => (m.unit === 'bytes' ? formatBytes(n) : formatCount(n));
  if (m.used === null) return `${m.label}: not measured`;
  const projection = m.projected !== null ? `; month-end at this rate ≈ ${fmt(m.projected)} (${Math.round(m.projectedPercent!)}%)` : '';
  return `${m.label}: ${fmt(m.used)} of ${fmt(m.limit)} (${Math.round(m.percent!)}%)${projection}`;
}

export const usageService = {
  /** Every few minutes: move the in-memory traffic counters into today's usage row. */
  async flushTraffic(): Promise<void> {
    const delta = traffic.drain();
    try {
      await usageRepository.addTraffic(db, istDay(), delta, process.memoryUsage().rss);
    } catch (error) {
      traffic.restore(delta);
      throw error;
    }
  },

  async sampleDatabaseSize(): Promise<number> {
    const bytes = await usageRepository.databaseSize(db);
    await usageRepository.setSizes(db, istDay(), { dbSizeBytes: bytes });
    return bytes;
  },

  /** R2 storage: exact from Cloudflare analytics when a token is set, else by listing the bucket. */
  async sampleR2(): Promise<void> {
    if (env.CLOUDFLARE_API_TOKEN && env.R2_ACCOUNT_ID) {
      const month = istMonth();
      const usage = await fetchR2Usage(env.R2_ACCOUNT_ID, env.CLOUDFLARE_API_TOKEN, month.start, new Date());
      if (usage) {
        cfR2 = { at: Date.now(), usage };
        await usageRepository.setSizes(db, istDay(), { r2StorageBytes: usage.storageBytes, r2ObjectCount: usage.objectCount });
        return;
      }
    }
    if (!r2.isConfigured()) return;
    const stats = await r2.storageStats();
    await usageRepository.setSizes(db, istDay(), { r2StorageBytes: stats.bytes, r2ObjectCount: stats.objects });
  },

  async report() {
    const now = new Date();
    const month = istMonth(now);
    const limits = await usageLimits();
    // Fold not-yet-flushed traffic in, so the screen is current to the second (deployed server
    // only: a laptop running the API against the same database must not add its traffic).
    if (isProduction) await usageService.flushTraffic().catch((error: unknown) => logger.warn({ err: error }, 'usage flush before report failed'));
    const [rows, sizes, fees, syncRows, openAlerts, tables, backups] = await Promise.all([
      usageRepository.range(db, month.firstDay, month.lastDay),
      usageRepository.latestSizes(db),
      usageRepository.razorpayFees(db, month.start),
      usageRepository.syncHealth(db),
      usageRepository.openAlerts(db),
      usageRepository.largestTables(db, 6),
      backupService.status(),
    ]);

    const sum = (pick: (row: (typeof rows)[number]) => number) => rows.reduce((total, row) => total + Number(pick(row)), 0);
    const httpOut = sum((row) => row.httpOutBytes);
    const dbOut = sum((row) => row.dbIngressBytes);
    const r2Up = sum((row) => row.r2UploadBytes);
    const renderOut = httpOut + dbOut + r2Up;
    const dbEgress = sum((row) => row.dbEgressBytes);
    const today = rows.find((row) => row.day === istDay(now));
    const peakRss = Math.max(Number(today?.peakRssBytes ?? 0), process.memoryUsage().rss);
    const cf = cfR2 && now.getTime() - cfR2.at < 2 * DAY_MS ? cfR2.usage : null;
    const classA = cf ? cf.classAOps : sum((row) => row.r2ClassAOps);
    const span = { daysElapsed: month.daysElapsed, daysInMonth: month.daysInMonth };

    const renderMetrics = [
      buildMetric(limits, {
        id: 'render.bandwidth', label: 'Outbound bandwidth', unit: 'bytes', used: renderOut, limit: limits.render.bandwidthBytes, cumulative: true, ...span,
        note: `App responses ${formatBytes(httpOut)} + database queries ${formatBytes(dbOut)} + image uploads ${formatBytes(r2Up)}. Above ${formatBytes(limits.render.bandwidthBytes)}: $${limits.render.bandwidthOverageUsdPerGb}/GB.`,
      }),
      buildMetric(limits, {
        id: 'render.memory', label: 'Memory (peak today)', unit: 'bytes', used: peakRss, limit: limits.render.memoryBytes, cumulative: false, ...span,
        note: 'The server restarts if it runs out of memory (orders in progress are safe; the app retries).',
      }),
    ];
    const overGb = (used: number | null, limit: number) => Math.max(0, ((used ?? 0) - limit) / GB);
    const renderNow = limits.render.monthlyUsd + overGb(renderOut, limits.render.bandwidthBytes) * limits.render.bandwidthOverageUsdPerGb;
    const renderEnd = limits.render.monthlyUsd + overGb(renderMetrics[0]!.projected, limits.render.bandwidthBytes) * limits.render.bandwidthOverageUsdPerGb;

    const supabaseMetrics = [
      buildMetric(limits, {
        id: 'supabase.db_size', label: 'Database size', unit: 'bytes', used: sizes.dbSizeBytes, limit: limits.supabase.dbSizeBytes, cumulative: false, ...span,
        note: `Over ${formatBytes(limits.supabase.dbSizeBytes)} the free database can be made read-only (orders would stop). Largest: ${tables
          .slice(0, 3)
          .map((table) => `${table.name} ${formatBytes(table.bytes)}`)
          .join(', ')}.`,
      }),
      buildMetric(limits, {
        id: 'supabase.egress', label: 'Data sent to the API (egress)', unit: 'bytes', used: dbEgress, limit: limits.supabase.egressBytes, cumulative: true, ...span,
        note: 'Measured on the API server; Supabase dashboard / SQL editor use adds a little on top.',
      }),
    ];

    const r2Metrics = [
      buildMetric(limits, {
        id: 'r2.storage', label: 'Image storage', unit: 'bytes', used: sizes.r2StorageBytes, limit: limits.r2.storageBytes, cumulative: false, ...span,
        note: sizes.r2ObjectCount !== null ? `${formatCount(sizes.r2ObjectCount)} files.` : 'Not sampled yet.',
      }),
      buildMetric(limits, {
        id: 'r2.class_a', label: 'Uploads & listings (Class A)', unit: 'count', used: classA, limit: limits.r2.classAOps, cumulative: true, ...span,
        note: cf ? 'From Cloudflare analytics.' : 'Counted by the API server.',
      }),
      buildMetric(limits, {
        id: 'r2.class_b', label: 'Image views (Class B)', unit: 'count', used: cf ? cf.classBOps : null, limit: limits.r2.classBOps, cumulative: true, ...span,
        note: cf ? 'From Cloudflare analytics.' : 'Set CLOUDFLARE_API_TOKEN (Account Analytics: Read) to measure; phones cache images, so this stays low.',
      }),
    ];
    const r2Cost = (storage: number | null, a: number | null, b: number | null) =>
      overGb(storage, limits.r2.storageBytes) * limits.r2.storageUsdPerGbMonth +
      (Math.max(0, (a ?? 0) - limits.r2.classAOps) / 1e6) * limits.r2.classAUsdPerMillion +
      (Math.max(0, (b ?? 0) - limits.r2.classBOps) / 1e6) * limits.r2.classBUsdPerMillion;

    const feeInr = Number(fees.fee);
    const services: ServiceUsage[] = [
      {
        id: 'render', name: 'Render (API server)', plan: `${limits.render.plan} — $${limits.render.monthlyUsd}/month`,
        costSoFarUsd: round2(renderNow), costProjectedUsd: round2(renderEnd), costInr: Math.round(renderEnd * limits.usdToInr),
        metrics: renderMetrics,
        notes: [`Build minutes: ${limits.render.pipelineMinutes}/month included (each deploy ≈ 3 min) — check Render → Billing.`],
      },
      {
        id: 'supabase', name: 'Supabase (database)', plan: `${limits.supabase.plan} — $0`,
        costSoFarUsd: 0, costProjectedUsd: 0, costInr: 0,
        metrics: supabaseMetrics,
        notes: ['Free plan: never billed, but going over a quota can get the project restricted. No automatic backups on Free.'],
      },
      {
        id: 'r2', name: 'Cloudflare R2 (product images)', plan: `${limits.r2.plan} — $0 up to the limits`,
        costSoFarUsd: round2(r2Cost(sizes.r2StorageBytes, classA, cf?.classBOps ?? null)),
        costProjectedUsd: round2(r2Cost(sizes.r2StorageBytes, r2Metrics[1]!.projected, r2Metrics[2]!.projected)),
        costInr: Math.round(r2Cost(sizes.r2StorageBytes, r2Metrics[1]!.projected, r2Metrics[2]!.projected) * limits.usdToInr),
        metrics: r2Metrics,
        notes: ['Image downloads (egress) are always free on R2.'],
      },
      {
        id: 'razorpay', name: 'Razorpay (payment fees)', plan: 'Per transaction',
        costSoFarUsd: round2(feeInr / limits.usdToInr), costProjectedUsd: round2((feeInr / month.daysElapsed) * month.daysInMonth / limits.usdToInr),
        costInr: Math.round(feeInr),
        metrics: [],
        notes: [
          `${fees.payments} online payment(s) this month, ₹${fees.amount} collected, fees ₹${fees.fee} (incl. GST ₹${fees.tax}).` +
            (fees.missingFee > 0 ? ` ${fees.missingFee} payment(s) without fee data.` : ''),
        ],
      },
    ];

    const syncProblems = syncRows.filter((row) => row.key.startsWith('gofrugal_') && row.consecutiveFailures >= 3);
    const health = {
      catalogSync: syncProblems.length === 0 ? { level: 'ok' as Level, message: 'Catalog sync is healthy.' } : {
        level: (syncProblems.some((row) => row.consecutiveFailures >= 8) ? 'critical' : 'warning') as Level,
        message: `Catalog sync failed ${Math.max(...syncProblems.map((row) => row.consecutiveFailures))} times in a row: ${(syncProblems[0]!.lastError ?? '').slice(0, 200)}`,
      },
    };

    const backupAgeHours = backups.lastSuccessAt ? (now.getTime() - backups.lastSuccessAt.getTime()) / 3_600_000 : null;
    const backupHealth: { level: Level; message: string } = !backups.configured
      ? { level: 'warning', message: 'Database backups are not set up (R2_BACKUP_BUCKET). Supabase Free keeps no backups of its own.' }
      : backups.consecutiveFailures >= 1 && (backupAgeHours === null || backupAgeHours > 30)
        ? { level: backups.consecutiveFailures >= 3 || (backupAgeHours ?? 99) > 72 ? 'critical' : 'warning', message: `Backup failing: ${(backups.lastError ?? 'unknown error').slice(0, 200)}` }
        : backupAgeHours === null
          ? { level: 'ok', message: 'First backup runs at 2 AM IST.' }
          : backupAgeHours > 72
            ? { level: 'critical', message: `Last successful backup was ${Math.round(backupAgeHours)} hours ago.` }
            : backupAgeHours > 36
              ? { level: 'warning', message: `Last successful backup was ${Math.round(backupAgeHours)} hours ago.` }
              : { level: 'ok', message: 'Backups are up to date.' };

    const estimateUsd = services.filter((service) => service.id !== 'razorpay').reduce((total, service) => total + service.costProjectedUsd, 0);
    return {
      month: month.label,
      asOf: now,
      daysElapsed: round2(month.daysElapsed),
      daysInMonth: month.daysInMonth,
      usdToInr: limits.usdToInr,
      /** Hosting bill at month end at the current rate (Render + R2 + Supabase), plus Razorpay fees so far. */
      totals: {
        hostingUsd: round2(estimateUsd),
        hostingInr: Math.round(estimateUsd * limits.usdToInr),
        paymentFeesInr: Math.round(feeInr),
      },
      services,
      health: { ...health, backups: backupHealth },
      backups,
      largestTables: tables,
      alerts: openAlerts.map(toPublicAlert),
      notifications: notifier.channels(),
      daily: rows.map((row) => ({
        day: row.day,
        renderOutBytes: Number(row.httpOutBytes) + Number(row.dbIngressBytes) + Number(row.r2UploadBytes),
        dbEgressBytes: Number(row.dbEgressBytes),
        requests: row.httpRequests,
      })),
    };
  },

  /** Compare usage with the limits; open / escalate / resolve alerts and notify. */
  async evaluate(): Promise<{ open: number }> {
    const report = await usageService.report();
    const checks: { metric: string; level: Level; title: string; message: string; data: unknown }[] = [];
    for (const service of report.services) {
      for (const m of service.metrics) {
        const percent = m.percent !== null ? Math.round(m.percent) : null;
        const projected = m.projectedPercent !== null ? Math.round(m.projectedPercent) : null;
        const headline =
          percent !== null && projected !== null && projected > percent && RANK[m.level] > 0 && percent < 70
            ? `${service.name}: ${m.label.toLowerCase()} heading to ${projected}% this month`
            : `${service.name}: ${m.label.toLowerCase()} at ${percent ?? '?'}%`;
        checks.push({ metric: m.id, level: m.level, title: headline, message: `${describe(m)}. ${m.note}`, data: { used: m.used, limit: m.limit, percent: m.percent, projectedPercent: m.projectedPercent } });
      }
    }
    checks.push({ metric: 'health.catalog_sync', level: report.health.catalogSync.level, title: 'Catalog sync is failing', message: report.health.catalogSync.message, data: null });
    checks.push({ metric: 'health.backups', level: report.health.backups.level, title: 'Database backups need attention', message: report.health.backups.message, data: null });

    const open = new Map((await usageRepository.openAlerts(db)).map((alert) => [alert.metric, alert]));
    const toNotify: { title: string; message: string; level: AlertLevel; id: number }[] = [];

    for (const check of checks) {
      const current = open.get(check.metric);
      if (check.level === 'ok') {
        if (current) {
          await usageRepository.updateAlert(db, current.id, { resolvedAt: new Date() });
          logger.info({ metric: check.metric }, 'usage alert resolved');
        }
        continue;
      }
      if (!current) {
        const created = await usageRepository.insertAlert(db, { metric: check.metric, level: check.level, title: check.title, message: check.message, data: check.data });
        if (created) toNotify.push({ ...check, level: check.level, id: created.id });
        logger.warn({ metric: check.metric, level: check.level, message: check.message }, 'usage alert opened');
        continue;
      }
      const escalated = RANK[check.level] > RANK[current.level];
      const repeat = check.level === 'critical' && (!current.notifiedAt || Date.now() - current.notifiedAt.getTime() > CRITICAL_REPEAT_MS);
      await usageRepository.updateAlert(db, current.id, {
        level: check.level,
        title: check.title,
        message: check.message,
        data: check.data,
        ...(escalated ? { acknowledgedAt: null, acknowledgedBy: null } : {}),
      });
      if (escalated || repeat) toNotify.push({ ...check, level: check.level, id: current.id });
    }

    if (toNotify.length > 0) {
      const subject = toNotify.length === 1 ? toNotify[0]!.title : `${toNotify.length} usage alerts need attention`;
      const sent = await notifier.send(subject, toNotify.flatMap((alert) => [`${alert.level.toUpperCase()}: ${alert.title}`, alert.message, '']));
      if (sent) for (const alert of toNotify) await usageRepository.updateAlert(db, alert.id, { notifiedAt: new Date() });
    }
    alertSummaryCache = null;
    return { open: (await usageRepository.openAlerts(db)).length };
  },

  /** For the admin's order board banner (polled), cached for a minute. */
  async openAlertSummary(): Promise<{ open: number; worst: AlertLevel | null }> {
    if (alertSummaryCache && Date.now() - alertSummaryCache.at < 60_000) return alertSummaryCache.value;
    const alerts = await usageRepository.openAlerts(db);
    const worst = alerts.reduce<AlertLevel | null>((top, alert) => (top === null || RANK[alert.level] > RANK[top] ? alert.level : top), null);
    alertSummaryCache = { at: Date.now(), value: { open: alerts.length, worst } };
    return alertSummaryCache.value;
  },

  async acknowledge(alertId: number, staffId: string) {
    const row = await usageRepository.acknowledge(db, alertId, staffId);
    alertSummaryCache = null;
    return row !== null;
  },

  async recentAlerts(limit = 50) {
    return (await usageRepository.recentAlerts(db, limit)).map(toPublicAlert);
  },

  /** Morning email: where every bill stands this month. */
  async sendDigest(): Promise<boolean> {
    if (!notifier.channels().email) return false;
    const report = await usageService.report();
    const lines = [
      `Usage for ${report.month} (day ${Math.floor(report.daysElapsed)} of ${report.daysInMonth}).`,
      `Expected hosting bill this month: $${report.totals.hostingUsd} (≈ ₹${report.totals.hostingInr}). Razorpay fees so far: ₹${report.totals.paymentFeesInr}.`,
      '',
      ...report.services.flatMap((service) => [
        `${service.name} — ${service.plan}`,
        ...service.metrics.map((m) => `  • ${describe(m)}${m.level !== 'ok' ? `  ← ${m.level.toUpperCase()}` : ''}`),
        ...service.notes.map((note) => `  ${note}`),
        '',
      ]),
      report.alerts.length > 0 ? `Open alerts: ${report.alerts.map((alert) => alert.title).join(' | ')}` : 'No open alerts. 👍',
    ];
    return notifier.send(`Daily usage: $${report.totals.hostingUsd} hosting, ${report.alerts.length} alert(s)`, lines);
  },
};

function toPublicAlert(alert: AdminAlert) {
  return {
    id: alert.id,
    metric: alert.metric,
    level: alert.level,
    title: alert.title,
    message: alert.message,
    createdAt: alert.createdAt,
    updatedAt: alert.updatedAt,
    resolvedAt: alert.resolvedAt,
    acknowledgedAt: alert.acknowledgedAt,
    notifiedAt: alert.notifiedAt,
  };
}
