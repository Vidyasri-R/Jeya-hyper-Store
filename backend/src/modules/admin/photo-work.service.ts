import { and, desc, eq, isNull, sql, type SQL } from 'drizzle-orm';
import { AppError } from '../../common/errors';
import { db } from '../../db/client';
import { categories, products, staffUsers } from '../../db/schema';
import { withPlaceholders } from '../catalog/catalog.service';
import { adminProductColumns } from './admin-products.service';

/** Active products still missing a photo. */
const needsPhoto = and(eq(products.isActive, true), isNull(products.imageUrl))!;

function encode(row: { photoPriority: number; id: number }) {
  return Buffer.from(JSON.stringify([row.photoPriority, row.id])).toString('base64url');
}
function decode(raw: string): { photoPriority: number; id: number } {
  try {
    const [p, id] = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as [unknown, unknown];
    if (typeof p === 'number' && typeof id === 'number') return { photoPriority: p, id };
  } catch {
    // fall through
  }
  throw new AppError('BAD_REQUEST', 'Invalid pagination cursor', { reason: 'cursor_invalid' });
}

/**
 * Photo work: the store's admin hands out products without photos (best first) to staff and
 * photo helpers, and sees each person's progress. A product leaves the queue once it has a photo.
 */
// Drizzle prints a lone-table column unqualified ("id"); inside the products subqueries that would
// mean products.id, so spell out the staff table.
const staffIdRef = sql`"staff_users"."id"`;

export const photoWorkService = {
  /** Products without photos, best first. assignee: a staff id, 'unassigned', or 'any'. */
  async queue(params: { assignee: string; categoryId?: number | undefined; cursor?: string | undefined; limit: number }) {
    const where: SQL[] = [needsPhoto];
    if (params.assignee === 'unassigned') where.push(isNull(products.photoAssigneeId));
    else if (params.assignee !== 'any') where.push(eq(products.photoAssigneeId, params.assignee));
    if (params.categoryId) where.push(sql`(${products.categoryId} = ${params.categoryId} OR ${products.categoryId} IN (SELECT id FROM ${categories} WHERE parent_id = ${params.categoryId}))`);
    if (params.cursor) {
      const c = decode(params.cursor);
      where.push(sql`(${products.photoPriority}, -${products.id}) < (${c.photoPriority}::int, -(${c.id}::bigint))`);
    }
    const rows = await db
      .select({ ...adminProductColumns, photoPriority: products.photoPriority })
      .from(products)
      .leftJoin(categories, eq(categories.id, products.categoryId))
      .where(and(...where))
      .orderBy(desc(products.photoPriority), products.id)
      .limit(params.limit + 1);
    const page = rows.slice(0, params.limit);
    const last = page.at(-1);
    return {
      products: await withPlaceholders(page.map((p) => ({ ...p, placeholderImageUrl: null as string | null }))),
      nextCursor: rows.length > params.limit && last ? encode(last) : null,
    };
  },

  /** Totals and each person's progress. */
  async summary() {
    const [totals] = await db
      .select({
        active: sql<number>`count(*) filter (where ${products.isActive})::int`,
        withPhoto: sql<number>`count(*) filter (where ${products.isActive} and ${products.imageUrl} is not null)::int`,
        unassigned: sql<number>`count(*) filter (where ${needsPhoto} and ${products.photoAssigneeId} is null)::int`,
        today: sql<number>`count(*) filter (where ${products.photoAt} >= date_trunc('day', now() at time zone 'Asia/Kolkata') at time zone 'Asia/Kolkata')::int`,
      })
      .from(products);
    const people = await db
      .select({
        staffId: staffUsers.id,
        name: staffUsers.name,
        username: staffUsers.username,
        role: staffUsers.role,
        isActive: staffUsers.isActive,
        open: sql<number>`(select count(*) from ${products} p where p.photo_assignee_id = ${staffIdRef} and p.is_active and p.image_url is null)::int`,
        done: sql<number>`(select count(*) from ${products} p where p.photo_by_id = ${staffIdRef} and p.image_url is not null)::int`,
        doneToday: sql<number>`(select count(*) from ${products} p where p.photo_by_id = ${staffIdRef} and p.photo_at >= date_trunc('day', now() at time zone 'Asia/Kolkata') at time zone 'Asia/Kolkata')::int`,
        lastPhotoAt: sql<string | null>`(select max(p.photo_at) from ${products} p where p.photo_by_id = ${staffIdRef})`,
      })
      .from(staffUsers)
      .orderBy(staffUsers.name);
    return {
      totals: {
        active: Number(totals?.active ?? 0),
        withPhoto: Number(totals?.withPhoto ?? 0),
        withoutPhoto: Number(totals?.active ?? 0) - Number(totals?.withPhoto ?? 0),
        unassigned: Number(totals?.unassigned ?? 0),
        today: Number(totals?.today ?? 0),
      },
      people: people.filter((p) => p.isActive && (p.role === 'photos' || p.open > 0 || p.done > 0 || p.role === 'admin' || p.role === 'staff')),
    };
  },

  /** Give [staffId] the next [count] unassigned products without photos (optionally in one category). */
  async assign(params: { staffId: string; count: number; categoryId?: number | undefined }) {
    const [person] = await db.select({ id: staffUsers.id, isActive: staffUsers.isActive }).from(staffUsers).where(eq(staffUsers.id, params.staffId)).limit(1);
    if (!person || !person.isActive) throw AppError.notFound('Staff member');
    const scope = params.categoryId
      ? sql`AND (category_id = ${params.categoryId} OR category_id IN (SELECT id FROM ${categories} WHERE parent_id = ${params.categoryId}))`
      : sql``;
    const rows = await db.execute<{ id: number }>(sql`
      UPDATE ${products} SET photo_assignee_id = ${params.staffId}, photo_assigned_at = now()
      WHERE id IN (
        SELECT id FROM ${products}
        WHERE is_active AND image_url IS NULL AND photo_assignee_id IS NULL ${scope}
        ORDER BY photo_priority DESC, id
        LIMIT ${params.count}
        FOR UPDATE SKIP LOCKED
      )
      RETURNING id`);
    return { assigned: rows.length };
  },

  /** Take back [staffId]'s unfinished products (they return to the unassigned queue). */
  async unassign(staffId: string) {
    const rows = await db
      .update(products)
      .set({ photoAssigneeId: null, photoAssignedAt: null })
      .where(and(eq(products.photoAssigneeId, staffId), needsPhoto))
      .returning({ id: products.id });
    return { released: rows.length };
  },

  /** May [staffId] (role) upload a photo for this product? Admins: any. Others: only their assignments. */
  async canUpload(productId: number, staffId: string, role: string) {
    if (role === 'admin') return true;
    const [row] = await db
      .select({ id: products.id })
      .from(products)
      .where(and(eq(products.id, productId), eq(products.photoAssigneeId, staffId)))
      .limit(1);
    return Boolean(row);
  },
};
