/**
 * End-to-end check of the Jeya Staff back office against the real database:
 *
 *   npm run smoke:staff
 *
 * Starts the API in-process, creates throw-away staff accounts (random passwords that never
 * leave this process), places test COD orders on the reviewer demo account, walks them through
 * the store workflow, exercises the admin APIs, then deletes everything it created.
 */
import { randomBytes } from 'node:crypto';
import type { AddressInfo } from 'node:net';
import { eq, inArray, like } from 'drizzle-orm';
import { createApp } from '../app';
import { hashPassword } from '../common/password';
import { closeDb, db } from '../db/client';
import { cartItems, orders, products, staffUsers, users } from '../db/schema';
import { r2 } from '../infra/r2';
import { ordersRepository } from '../modules/orders/orders.repository';

type Json = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any

let base = '';
let failures = 0;
const createdOrders: string[] = [];
const tag = randomBytes(3).toString('hex');

async function call(method: string, path: string, opts: { body?: unknown; token?: string; raw?: { bytes: Buffer; type: string } } = {}) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      ...(opts.body !== undefined ? { 'content-type': 'application/json' } : {}),
      ...(opts.raw ? { 'content-type': opts.raw.type } : {}),
      ...(opts.token ? { authorization: `Bearer ${opts.token}` } : {}),
    },
    ...(opts.body !== undefined ? { body: JSON.stringify(opts.body) } : {}),
    ...(opts.raw ? { body: new Uint8Array(opts.raw.bytes) } : {}),
  });
  const text = await res.text();
  return { status: res.status, json: (text ? JSON.parse(text) : {}) as Json };
}

function check(label: string, ok: boolean, detail?: unknown) {
  if (ok) console.log(`  ✔ ${label}`);
  else {
    failures++;
    console.log(`  ✘ ${label}`, detail === undefined ? '' : JSON.stringify(detail).slice(0, 600));
  }
}

const randomPassword = () => `${randomBytes(9).toString('base64url')}7a`;

async function reservedOf(ids: number[]) {
  const rows = await db.select({ id: products.id, reserved: products.reservedQuantity }).from(products).where(inArray(products.id, ids));
  return new Map(rows.map((row) => [row.id, row.reserved]));
}

async function placeCodOrder(customer: string, addressId: string, lines: { productId: number; quantity: string }[]) {
  await call('DELETE', '/v1/cart', { token: customer });
  for (const line of lines) await call('PUT', `/v1/cart/items/${line.productId}`, { token: customer, body: { quantity: line.quantity } });
  const quote = await call('POST', '/v1/checkout/quote', { token: customer, body: { addressId } });
  const placed = await call('POST', '/v1/orders', {
    token: customer,
    body: { addressId, paymentMethod: 'cod', idempotencyKey: `smoke-${tag}-${createdOrders.length}`, expectedTotal: quote.json.quote?.totals?.total },
  });
  if (placed.json.order?.id) createdOrders.push(placed.json.order.id);
  return { quote, placed };
}

async function main() {
  const server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  console.log(`Staff smoke test → in-process API (${base}) on the real database\n`);

  // Demo customer cart, restored at the end.
  const [demo] = await db.select({ id: users.id }).from(users).where(eq(users.phone, '919999999999')).limit(1);
  const savedCart = demo ? await db.select().from(cartItems).where(eq(cartItems.userId, demo.id)) : [];

  const adminPass = randomPassword();
  const staffTemp = randomPassword();
  const admin = await db.insert(staffUsers).values({ username: `smoke-admin-${tag}`, name: 'Smoke Admin', role: 'admin', passwordHash: await hashPassword(adminPass), mustChangePassword: false }).returning();
  await db.insert(staffUsers).values({ username: `smoke-staff-${tag}`, name: 'Smoke Packer', role: 'staff', passwordHash: await hashPassword(staffTemp), mustChangePassword: true });

  try {
    console.log('Staff login');
    const wrong = await call('POST', '/v1/staff/auth/login', { body: { username: `smoke-staff-${tag}`, password: 'wrong-pass-1' } });
    check('wrong password → 401', wrong.status === 401 && wrong.json.error?.details?.reason === 'credentials_invalid', wrong.json);
    const unknown = await call('POST', '/v1/staff/auth/login', { body: { username: `nobody-${tag}`, password: 'whatever-1' } });
    check('unknown user → same 401', unknown.status === 401 && unknown.json.error?.message === wrong.json.error?.message, unknown.json);
    const firstLogin = await call('POST', '/v1/staff/auth/login', { body: { username: `SMOKE-STAFF-${tag}`, password: staffTemp, deviceInfo: 'smoke' } });
    check('temporary password works (username case-insensitive)', firstLogin.status === 200 && firstLogin.json.staff?.mustChangePassword === true, firstLogin.json);
    const blocked = await call('GET', '/v1/staff/orders/summary', { token: firstLogin.json.accessToken });
    check('board blocked until password changed (403)', blocked.status === 403 && blocked.json.error?.details?.reason === 'password_change_required', blocked.json);
    const weak = await call('POST', '/v1/staff/me/password', { token: firstLogin.json.accessToken, body: { currentPassword: staffTemp, newPassword: 'password1' } });
    check('weak new password rejected', weak.status === 422, weak.json);
    const staffPass = randomPassword();
    const changed = await call('POST', '/v1/staff/me/password', { token: firstLogin.json.accessToken, body: { currentPassword: staffTemp, newPassword: staffPass } });
    check('password changed → fresh session', changed.status === 200 && changed.json.staff?.mustChangePassword === false && changed.json.accessToken, changed.json);
    const oldSession = await call('GET', '/v1/staff/me', { token: firstLogin.json.accessToken });
    check('old session revoked after password change', oldSession.status === 401, oldSession.json);
    const staffToken = changed.json.accessToken as string;
    const refreshed = await call('POST', '/v1/staff/auth/refresh', { body: { refreshToken: changed.json.refreshToken } });
    check('refresh rotates tokens', refreshed.status === 200 && refreshed.json.refreshToken !== changed.json.refreshToken, refreshed.json);
    const replay = await call('POST', '/v1/staff/auth/refresh', { body: { refreshToken: changed.json.refreshToken } });
    check('refresh token replay rejected', replay.status === 401, replay.json);

    const adminLogin = await call('POST', '/v1/staff/auth/login', { body: { username: `smoke-admin-${tag}`, password: adminPass } });
    check('admin login', adminLogin.status === 200 && adminLogin.json.staff?.role === 'admin', adminLogin.json);
    const adminToken = adminLogin.json.accessToken as string;

    console.log('\nSeparation from customer accounts');
    await call('POST', '/v1/auth/otp/request', { body: { phone: '9999999999' } });
    const customerLogin = await call('POST', '/v1/auth/otp/verify', { body: { phone: '9999999999', otp: '123456' } });
    const customer = customerLogin.json.accessToken as string;
    check('demo customer signed in', customerLogin.status === 200 && Boolean(customer), customerLogin.json);
    const customerOnStaff = await call('GET', '/v1/staff/orders/summary', { token: customer });
    check('customer token rejected by staff API (401)', customerOnStaff.status === 401, customerOnStaff.json);
    const staffOnCustomer = await call('GET', '/v1/cart', { token: staffToken });
    check('staff token rejected by customer API (401)', staffOnCustomer.status === 401, staffOnCustomer.json);
    const staffOnAdmin = await call('GET', '/v1/admin/staff', { token: staffToken });
    check('staff (non-admin) blocked from admin API (403)', staffOnAdmin.status === 403, staffOnAdmin.json);

    console.log('\nOrder workflow (COD)');
    const addresses = await call('GET', '/v1/me/addresses', { token: customer });
    const address = (addresses.json.addresses as Json[] | undefined)?.find((entry) => entry.serviceable !== false);
    check('demo account has a deliverable address', Boolean(address), addresses.json);
    const listing = await call('GET', '/v1/products?inStock=true&limit=40');
    const items = (listing.json.items as Json[]) ?? [];
    const loose = items.find((item) => item.isLoose);
    const packed = items.find((item) => !item.isLoose && Number(item.available) >= 3);
    const picks = [packed, loose].filter(Boolean) as Json[];
    check('found in-stock products to order', picks.length >= 1, listing.json);
    const lines = picks.map((item) => ({ productId: item.id as number, quantity: item.isLoose ? '1' : '2' }));
    const ids = lines.map((line) => line.productId);
    const before = await reservedOf(ids);

    const { placed } = await placeCodOrder(customer, address!.id, lines);
    check('customer places a COD order', placed.status === 201, placed.json);
    const orderId = placed.json.order?.id as string;
    const reservedAfterPlace = await reservedOf(ids);
    check('stock reserved', ids.every((id) => Number(reservedAfterPlace.get(id)) > Number(before.get(id))), [...reservedAfterPlace]);

    const summary = await call('GET', '/v1/staff/orders/summary', { token: staffToken });
    check('summary counts the new order', summary.status === 200 && summary.json.counts?.new >= 1, summary.json);
    const newTab = await call('GET', '/v1/staff/orders?tab=new', { token: staffToken });
    check('order on the "new" tab', (newTab.json.orders as Json[] | undefined)?.some((order) => order.id === orderId) === true, newTab.json);
    const search = await call('GET', `/v1/staff/orders?q=${encodeURIComponent(String(String(placed.json.order.orderNumber).split('-').pop()))}`, { token: staffToken });
    check('search by order number finds it', (search.json.orders as Json[] | undefined)?.some((order) => order.id === orderId) === true, search.json);
    const detail = await call('GET', `/v1/staff/orders/${orderId}`, { token: staffToken });
    check('detail shows items, customer and next step', detail.status === 200 && detail.json.order?.items?.length === lines.length && detail.json.order?.actions?.next?.to === 'packing', detail.json);

    const stale = await call('POST', `/v1/staff/orders/${orderId}/advance`, { token: staffToken, body: { from: 'confirmed', to: 'packing' } });
    check('stale tap refused (409 order_changed)', stale.status === 409 && stale.json.error?.details?.reason === 'order_changed', stale.json);
    const skip = await call('POST', `/v1/staff/orders/${orderId}/advance`, { token: staffToken, body: { from: 'placed', to: 'delivered' } });
    check('skipping steps refused (400)', skip.status === 400, skip.json);
    const packing = await call('POST', `/v1/staff/orders/${orderId}/advance`, { token: staffToken, body: { from: 'placed', to: 'packing' } });
    check('start packing', packing.status === 200 && packing.json.order?.status === 'packing', packing.json);

    const first = lines[0]!;
    const short = { productId: first.productId, packedQuantity: picks[0]!.isLoose ? '0.8' : '1' };
    const over = await call('POST', `/v1/staff/orders/${orderId}/advance`, { token: staffToken, body: { from: 'packing', to: 'ready_for_delivery', packedItems: [{ productId: first.productId, packedQuantity: '99' }] } });
    check('packing more than ordered refused', over.status === 400, over.json);
    const ready = await call('POST', `/v1/staff/orders/${orderId}/advance`, { token: staffToken, body: { from: 'packing', to: 'ready_for_delivery', packedItems: [short] } });
    const due = ready.json.order?.amountToCollect as string;
    check('packed with one item short → lower final amount', ready.status === 200 && ready.json.order?.finalAmount !== null && Number(due) < Number(placed.json.order.totalAmount), ready.json);
    const out = await call('POST', `/v1/staff/orders/${orderId}/advance`, { token: staffToken, body: { from: 'ready_for_delivery', to: 'out_for_delivery' } });
    check('out for delivery', out.status === 200 && out.json.order?.status === 'out_for_delivery', out.json);
    const noCash = await call('POST', `/v1/staff/orders/${orderId}/advance`, { token: staffToken, body: { from: 'out_for_delivery', to: 'delivered' } });
    check('delivery needs the cash amount', noCash.status === 400 && noCash.json.error?.details?.reason === 'cod_amount_required', noCash.json);
    const wrongCash = await call('POST', `/v1/staff/orders/${orderId}/advance`, { token: staffToken, body: { from: 'out_for_delivery', to: 'delivered', codCollectedAmount: '1.00' } });
    check('cash mismatch without a note refused', wrongCash.status === 400 && wrongCash.json.error?.details?.reason === 'cod_amount_mismatch', wrongCash.json);
    const delivered = await call('POST', `/v1/staff/orders/${orderId}/advance`, { token: staffToken, body: { from: 'out_for_delivery', to: 'delivered', codCollectedAmount: due } });
    check('delivered, cash recorded, marked paid', delivered.status === 200 && delivered.json.order?.status === 'delivered' && delivered.json.order?.paymentStatus === 'paid' && delivered.json.order?.cod?.collectedAmount === due, delivered.json);
    const retry = await call('POST', `/v1/staff/orders/${orderId}/advance`, { token: staffToken, body: { from: 'out_for_delivery', to: 'delivered', codCollectedAmount: due } });
    check('retried tap is harmless', retry.status === 200 && retry.json.order?.status === 'delivered', retry.json);
    const reservedAfterDelivery = await reservedOf(ids);
    check('stock hold released on delivery', ids.every((id) => reservedAfterDelivery.get(id) === before.get(id)), { before: [...before], after: [...reservedAfterDelivery] });
    const history = (delivered.json.order?.history as Json[] | undefined) ?? [];
    check('history credits the staff member', history.filter((entry) => entry.by === 'Smoke Packer').length === 4, history);
    const customerView = await call('GET', `/v1/orders/${orderId}`, { token: customer });
    check('customer sees Delivered and the final amount', customerView.json.order?.status === 'delivered' && customerView.json.order?.finalAmount === due, customerView.json);

    console.log('\nStore cancellation');
    const second = await placeCodOrder(customer, address!.id, [{ productId: first.productId, quantity: '1' }]);
    const secondId = second.placed.json.order?.id as string;
    check('second order placed', second.placed.status === 201, second.placed.json);
    const noReason = await call('POST', `/v1/staff/orders/${secondId}/cancel`, { token: staffToken, body: { from: 'placed' } });
    check('cancel needs a reason', noReason.status === 422, noReason.json);
    const cancelled = await call('POST', `/v1/staff/orders/${secondId}/cancel`, { token: staffToken, body: { from: 'placed', reason: 'Item damaged in store' } });
    check('cancelled by store', cancelled.status === 200 && cancelled.json.order?.status === 'cancelled' && /damaged/.test(cancelled.json.order?.cancelledReason ?? ''), cancelled.json);
    const reservedAfterCancel = await reservedOf([first.productId]);
    check('stock hold released on cancel', reservedAfterCancel.get(first.productId) === before.get(first.productId), [...reservedAfterCancel]);

    console.log('\nPagination (keyset cursors)');
    const page1 = await call('GET', '/v1/orders?limit=1', { token: customer });
    const page2 = page1.json.nextCursor ? await call('GET', `/v1/orders?limit=1&cursor=${page1.json.nextCursor}`, { token: customer }) : null;
    check('customer orders page 2 loads and differs', page2?.status === 200 && page2.json.orders?.[0]?.id !== page1.json.orders?.[0]?.id, page2?.json ?? page1.json);
    const staffPage1 = await call('GET', '/v1/staff/orders?tab=all&limit=1', { token: staffToken });
    const staffPage2 = staffPage1.json.nextCursor ? await call('GET', `/v1/staff/orders?tab=all&limit=1&cursor=${staffPage1.json.nextCursor}`, { token: staffToken }) : null;
    check('staff board page 2 loads and differs', staffPage2?.status === 200 && staffPage2.json.orders?.[0]?.id !== staffPage1.json.orders?.[0]?.id, staffPage2?.json ?? staffPage1.json);

    console.log('\nAdmin: staff accounts');
    const list = await call('GET', '/v1/admin/staff', { token: adminToken });
    check('list staff', list.status === 200 && (list.json.staff as Json[]).some((s) => s.username === `smoke-staff-${tag}`), list.json);
    const created = await call('POST', '/v1/admin/staff', { token: adminToken, body: { username: `smoke-tmp-${tag}`, name: 'Smoke Temp', phone: '9876543210', role: 'staff' } });
    check('create staff → one-time temporary password', created.status === 201 && /^[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}$/.test(created.json.temporaryPassword ?? ''), { status: created.status, staff: created.json.staff });
    const dup = await call('POST', '/v1/admin/staff', { token: adminToken, body: { username: `smoke-tmp-${tag}`, name: 'Again', role: 'staff' } });
    check('duplicate username refused (409)', dup.status === 409, dup.json);
    const tmpId = created.json.staff?.id as string;
    for (let i = 0; i < 5; i++) await call('POST', '/v1/staff/auth/login', { body: { username: `smoke-tmp-${tag}`, password: `wrong-guess-${i}` } });
    const locked = await call('POST', '/v1/staff/auth/login', { body: { username: `smoke-tmp-${tag}`, password: created.json.temporaryPassword } });
    check('5 wrong guesses lock the account, even for the right password (429)', locked.status === 429 && locked.json.error?.details?.reason === 'account_locked', locked.json);
    const reset = await call('POST', `/v1/admin/staff/${tmpId}/reset-password`, { token: adminToken });
    const tmpLogin = await call('POST', '/v1/staff/auth/login', { body: { username: `smoke-tmp-${tag}`, password: reset.json.temporaryPassword } });
    check('admin reset unlocks with a new temporary password', reset.status === 200 && tmpLogin.status === 200 && tmpLogin.json.staff?.mustChangePassword === true, tmpLogin.json);
    const disabled = await call('PATCH', `/v1/admin/staff/${tmpId}`, { token: adminToken, body: { isActive: false } });
    const afterDisable = await call('GET', '/v1/staff/me', { token: tmpLogin.json.accessToken });
    check('disabling signs the person out at once', disabled.status === 200 && afterDisable.status === 401, afterDisable.json);
    const self = await call('PATCH', `/v1/admin/staff/${admin[0]!.id}`, { token: adminToken, body: { isActive: false } });
    check('admin cannot disable themselves', self.status === 409, self.json);

    console.log('\nAdmin: settings, dashboard, usage');
    const settings = await call('GET', '/v1/admin/settings', { token: adminToken });
    check('settings readable', settings.status === 200 && settings.json.settings?.['delivery.rules']?.tiers?.length > 0, settings.json);
    const sameInfo = settings.json.settings?.['store.info'];
    const write = await call('PUT', '/v1/admin/settings/store.info', { token: adminToken, body: { value: sameInfo } });
    check('settings write validated (same values written back)', write.status === 200, write.json);
    const badRules = await call('PUT', '/v1/admin/settings/delivery.rules', { token: adminToken, body: { value: { tiers: [] } } });
    check('invalid delivery rules refused (422)', badRules.status === 422, badRules.json);
    const dashboard = await call('GET', '/v1/admin/dashboard?days=7', { token: adminToken });
    check('sales dashboard', dashboard.status === 200 && dashboard.json.totals && Array.isArray(dashboard.json.topProducts), dashboard.json);
    const usage = await call('POST', '/v1/admin/usage/refresh', { token: adminToken });
    check('usage & bills report', usage.status === 200 && usage.json.services?.length === 4 && usage.json.totals?.hostingUsd >= 7, usage.json);
    const adminSummary = await call('GET', '/v1/staff/orders/summary', { token: adminToken });
    check('admin board summary carries alerts', adminSummary.status === 200 && adminSummary.json.alerts !== null, adminSummary.json);

    console.log('\nAdmin: product photo');
    if (!r2.isConfigured()) {
      console.log('  – skipped (R2 not configured locally)');
    } else {
      const noImage = await call('GET', '/v1/admin/products?filter=no_image&limit=1', { token: adminToken });
      const product = (noImage.json.products as Json[] | undefined)?.[0];
      check('list products without a photo', noImage.status === 200 && Boolean(product), noImage.json);
      if (product) {
        const sharp = (await import('sharp')).default;
        const photo = await sharp({ create: { width: 1600, height: 1200, channels: 3, background: '#e8f5e9' } }).jpeg().toBuffer();
        const upload = await call('PUT', `/v1/admin/products/${product.id}/image`, { token: adminToken, raw: { bytes: photo, type: 'image/jpeg' } });
        check('photo uploaded as small WebP', upload.status === 200 && /\.webp$/.test(upload.json.imageUrl ?? '') && upload.json.bytes < 60_000, upload.json);
        const notImage = await call('PUT', `/v1/admin/products/${product.id}/image`, { token: adminToken, raw: { bytes: Buffer.from('not an image'), type: 'image/png' } });
        check('non-image refused', notImage.status === 400, notImage.json);
        const key = upload.json.imageUrl ? r2.keyFromUrl(upload.json.imageUrl) : null;
        const removed = await call('DELETE', `/v1/admin/products/${product.id}/image`, { token: adminToken });
        check('photo removed (DB + R2)', removed.status === 204 && key !== null && !(await r2.exists(key)), removed.json);
      }
    }
  } finally {
    // Clean up everything this run created.
    const leftovers = createdOrders.length ? await db.select({ id: orders.id, status: orders.orderStatus }).from(orders).where(inArray(orders.id, createdOrders)) : [];
    const holding = leftovers.filter((order) => !['delivered', 'cancelled', 'payment_failed'].includes(order.status)).map((order) => order.id);
    if (holding.length) await ordersRepository.releaseForOrders(db, holding);
    if (createdOrders.length) await db.delete(orders).where(inArray(orders.id, createdOrders));
    await db.delete(staffUsers).where(like(staffUsers.username, `smoke-%-${tag}`));
    if (demo) {
      await db.delete(cartItems).where(eq(cartItems.userId, demo.id));
      if (savedCart.length) await db.insert(cartItems).values(savedCart);
    }
    console.log(`\nCleaned up ${createdOrders.length} test order(s) and the smoke staff accounts.`);
    server.close();
    await closeDb();
  }

  console.log(failures === 0 ? '\n🎉 Staff back office works end to end.' : `\n❌ ${failures} check(s) failed.`);
  process.exitCode = failures === 0 ? 0 : 1;
}

main().catch(async (error: unknown) => {
  console.error('❌ smoke test crashed:', error);
  process.exitCode = 1;
});
