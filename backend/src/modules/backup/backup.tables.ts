import { sql, type SQL } from 'drizzle-orm';

/**
 * What goes into a backup, in restore order (parents before children).
 *
 * Supabase Free has no backups, so the API exports the business data itself. A monthly full
 * backup plus small daily incrementals keeps database egress low (5 GB/month free): a daily
 * run only reads the rows that changed since the previous one.
 *
 * Deliberately left out: sessions, OTPs and carts (short-lived), webhook logs (audit only),
 * usage/alert rows (monitoring), sync state (rebuilt by the POS sync).
 */
export type BackupTable = {
  table: string;
  /** Single-column primary key, used to page through the table and to upsert on restore. */
  pk: string;
  pkType: 'uuid' | 'bigint' | 'integer' | 'text';
  /** Generated columns can't be restored, so they're not dumped either. */
  exclude?: string[];
  /** Rows never backed up (e.g. the backup job's own bookkeeping). */
  skipRows?: SQL;
  /**
   * Incremental filter for rows changed since `since` (an ISO timestamp parameter).
   * null = tiny table, always dumped whole; 'full-only' = only in the monthly full backup.
   */
  changed: ((since: SQL) => SQL) | null | 'full-only';
};

const changedOrders = (since: SQL) => sql`select id from orders where updated_at > ${since}`;

export const BACKUP_TABLES: BackupTable[] = [
  { table: 'staff_users', pk: 'id', pkType: 'uuid', changed: (since) => sql`updated_at > ${since}` },
  { table: 'users', pk: 'id', pkType: 'uuid', changed: (since) => sql`updated_at > ${since}` },
  { table: 'addresses', pk: 'id', pkType: 'uuid', changed: (since) => sql`updated_at > ${since}` },
  // backup.last is written by the backup itself after it finishes — not data worth restoring.
  { table: 'app_config', pk: 'key', pkType: 'text', changed: null, skipRows: sql`key = 'backup.last'` },
  { table: 'serviceable_pincodes', pk: 'pincode', pkType: 'text', changed: null },
  { table: 'categories', pk: 'id', pkType: 'integer', changed: 'full-only' },
  {
    table: 'products',
    pk: 'id',
    pkType: 'bigint',
    exclude: ['search_vector'],
    // Products in changed orders (so order lines restore against them) and products whose
    // store-owned fields (photo, Tamil name, description, ranking) may have been edited.
    changed: (since) => sql`id in (select product_id from order_items where order_id in (${changedOrders(since)}))
      or (updated_at > ${since} and (image_url is not null or name_ta is not null or description is not null or sort_rank <> 0 or safety_stock <> 0))`,
  },
  { table: 'orders', pk: 'id', pkType: 'uuid', changed: (since) => sql`updated_at > ${since}` },
  // Lines have no updated_at; packing changes always touch their order, so take every line of a changed order.
  { table: 'order_items', pk: 'id', pkType: 'bigint', changed: (since) => sql`order_id in (${changedOrders(since)})` },
  { table: 'order_status_history', pk: 'id', pkType: 'bigint', changed: (since) => sql`created_at > ${since}` },
  { table: 'payments', pk: 'id', pkType: 'uuid', changed: (since) => sql`updated_at > ${since}` },
  { table: 'refunds', pk: 'id', pkType: 'uuid', changed: (since) => sql`updated_at > ${since}` },
];
