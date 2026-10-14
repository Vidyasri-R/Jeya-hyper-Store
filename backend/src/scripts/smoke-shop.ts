/**
 * Customer scenarios end to end against the real database (the shop side of smoke:staff):
 *
 *   npm run smoke:shop
 *
 * Starts the API in-process and shops as the reviewer demo account: catalogue and search edge cases,
 * cart limits, addresses in and out of the delivery area, quotes and free delivery, price-change
 * and double-tap protection, cancelling, an online-payment order (Razorpay order only, never paid)
 * and the security boundaries. Test orders are marked announced at once so the shop's phones don't
 * ring; everything it creates is deleted at the end and the demo cart is restored.
 */
import { randomBytes, randomUUID } from 'node:crypto';
import type { AddressInfo } from 'node:net';
import { eq, inArray } from 'drizzle-orm';
import { createApp } from '../app';
import { closeDb, db } from '../db/client';
import { addresses, cartItems, orders, payments, products, refunds, users } from '../db/schema';
import { ordersRepository } from '../modules/orders/orders.repository';

type Json = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any

let base = '';
let failures = 0;
const createdOrders: string[] = [];
const createdAddresses: string[] = [];
const tag = randomBytes(3).toString('hex');

async function call(method: string, path: string, opts: { body?: unknown; token?: string; headers?: Record<string, string> } = {}) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      ...(opts.body !== undefined ? { 'content-type': 'application/json' } : {}),
      ...(opts.token ? { authorization: `Bearer ${opts.token}` } : {}),
      ...opts.headers,
    },
    ...(opts.body !== undefined ? { body: JSON.stringify(opts.body) } : {}),
  });
  const text = await res.text();
  let json: Json = {};
  try {
    json = text ? (JSON.parse(text) as Json) : {};
  } catch {
    json = { text: text.slice(0, 200) };
  }
  return { status: res.status, json };
}

function check(label: string, ok: boolean, detail?: unknown) {
  if (ok) console.log(`  ✔ ${label}`);
  else {
    failures++;
    console.log(`  ✘ ${label}`, detail === undefined ? '' : JSON.stringify(detail).slice(0, 500));
  }
}

/** Silent: announced an hour ago, so the live server's alert check never rings for it. */
async function silence(orderId: string) {
  createdOrders.push(orderId);
  await db.update(orders).set({ alertedAt: new Date(Date.now() - 3600_000) }).where(eq(orders.id, orderId));
}

async function main() {
  const server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  console.log(`Shop smoke test → in-process API (${base}) on the real database\n`);

  const [demo] = await db.select({ id: users.id }).from(users).where(eq(users.phone, '919999999999')).limit(1);
  const savedCart = demo ? await db.select().from(cartItems).where(eq(cartItems.userId, demo.id)) : [];

  try {
    console.log('Catalogue & search');
    const home = await call('GET', '/v1/home');
    check('home loads with products', home.status === 200 && JSON.stringify(home.json).includes('sellingPrice'), home.json);
    const cats = await call('GET', '/v1/categories');
    const catList = (cats.json.categories as Json[]) ?? [];
    check('categories load', cats.status === 200 && catList.length >= 10, cats.json);
    const atta = await call('GET', '/v1/products?q=atta&limit=20');
    check('search "atta" finds atta', atta.status === 200 && (atta.json.items as Json[]).some((p) => /atta/i.test(p.name)), atta.json);
    const typo = await call('GET', '/v1/products?q=biscut&limit=20');
    check('typo "biscut" still finds biscuits', typo.status === 200 && (typo.json.items as Json[]).some((p) => /biscuit/i.test(`${p.name} ${p.categoryId}`)), typo.json);
    const junk = await call('GET', '/v1/products?q=webfefbeifjnerfqoqmskdmod&limit=20');
    check('gibberish finds nothing', junk.status === 200 && (junk.json.items as Json[]).length === 0, junk.json);
    const sqlish = await call('GET', `/v1/products?q=${encodeURIComponent("' OR 1=1 --")}&limit=5`);
    check('SQL-looking search is just text (no error)', sqlish.status === 200 || sqlish.status === 422, sqlish.json);
    const tamil = await call('GET', `/v1/products?q=${encodeURIComponent('அரிசி')}&limit=5`);
    check('Tamil search answers (no error)', tamil.status === 200, tamil.json);
    const long = await call('GET', `/v1/products?q=${'a'.repeat(500)}`);
    check('very long search refused cleanly (4xx, not 500)', long.status >= 400 && long.status < 500, long.status);
    const suggest = await call('GET', '/v1/search/suggest?q=bis');
    check('suggestions for "bis"', suggest.status === 200 && JSON.stringify(suggest.json).toLowerCase().includes('bis'), suggest.json);
    const emptySuggest = await call('GET', '/v1/search/suggest?q=');
    check('empty suggestion query handled (not 500)', emptySuggest.status < 500, emptySuggest.status);
    const missing = await call('GET', '/v1/products/no-such-product-xyz');
    check('unknown product → 404', missing.status === 404, missing.json);
    const sized = await call('GET', '/v1/products?q=aashirvaad%20atta&limit=5');
    const withSizes = (sized.json.items as Json[]).find((p) => (p.variants as Json[] | undefined)?.length);
    check('one card per product with its sizes', Boolean(withSizes), sized.json);
    const detail = withSizes ? await call('GET', `/v1/products/${withSizes.slug}`) : null;
    check('product page loads', detail?.status === 200, detail?.json);
    const leaf = catList.flatMap((c) => [c, ...((c.children as Json[]) ?? [])]).find((c) => !(c.children as Json[] | undefined)?.length);
    const inCat = leaf ? await call('GET', `/v1/products?categoryId=${leaf.id}&limit=10`) : null;
    check('category listing loads', inCat?.status === 200, inCat?.json);
    const pub = JSON.stringify(atta.json);
    check('no cost price in public product data', !/cost_?price|costPrice|landing/i.test(pub));

    console.log('\nSign-in & security boundaries');
    const noAuth = await call('GET', '/v1/cart');
    check('cart without sign-in → 401', noAuth.status === 401, noAuth.json);
    const forged = await call('GET', '/v1/cart', { token: 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.forged' });
    check('forged token → 401', forged.status === 401, forged.json);
    await call('POST', '/v1/auth/otp/request', { body: { phone: '9999999999' } });
    const login = await call('POST', '/v1/auth/otp/verify', { body: { phone: '9999999999', otp: '123456' } });
    const token = login.json.accessToken as string;
    check('demo customer signs in', login.status === 200 && Boolean(token), login.json);
    const badOtp = await call('POST', '/v1/auth/otp/verify', { body: { phone: '9999999999', otp: '000000' } });
    check('wrong code refused', badOtp.status === 401, badOtp.json);
    const notPhone = await call('POST', '/v1/auth/otp/request', { body: { phone: '12345' } });
    check('invalid mobile number refused (422)', notPhone.status === 422, notPhone.json);
    const adminAsCustomer = await call('GET', '/v1/admin/settings', { token });
    check('customer token can’t open admin (401)', adminAsCustomer.status === 401, adminAsCustomer.json);
    const someoneElse = await call('GET', `/v1/orders/${randomUUID()}`, { token });
    check('another order id → 404 (no peeking)', someoneElse.status === 404, someoneElse.json);
    const badId = await call('GET', '/v1/orders/not-a-uuid', { token });
    check('malformed order id → 422', badId.status === 422 || badId.status === 400, badId.json);
    const bigBody = await call('PATCH', '/v1/me', { token, body: { name: 'x'.repeat(200_000) } });
    check('oversized request body refused (413/4xx)', bigBody.status >= 400 && bigBody.status < 500, bigBody.status);

    console.log('\nCart rules');
    await call('DELETE', '/v1/cart', { token });
    const emptyQuote = await call('POST', '/v1/checkout/quote', { token, body: { addressId: randomUUID() } });
    check('quote with an empty cart refused', emptyQuote.status >= 400 && emptyQuote.status < 500, emptyQuote.json);
    const listing = await call('GET', '/v1/products?inStock=true&limit=50');
    const items = (listing.json.items as Json[]) ?? [];
    const packed = items.find((p) => !p.isLoose && p.stockStatus === 'in_stock' && Number(p.maxPurchasableQty) >= 3 && Number(p.sellingPrice) >= 20);
    const loose = items.find((p) => p.isLoose);
    check('found products to shop with', Boolean(packed), listing.json);
    const pid = packed!.id as number;
    const add = await call('PUT', `/v1/cart/items/${pid}`, { token, body: { quantity: '2' } });
    check('add 2 to cart', add.status === 200, add.json);
    const tooMany = await call('PUT', `/v1/cart/items/${pid}`, { token, body: { quantity: String(Number(packed!.maxPurchasableQty) + 5) } });
    const cappedLine = (tooMany.json.cart?.items as Json[] | undefined)?.find((l) => l.productId === pid);
    check('more than the limit is refused or capped', (tooMany.status >= 400 && tooMany.status < 500) || Number(cappedLine?.quantity) <= Number(packed!.maxPurchasableQty), tooMany.json);
    const half = await call('PUT', `/v1/cart/items/${pid}`, { token, body: { quantity: '1.5' } });
    check('half a packet refused', half.status >= 400 && half.status < 500, half.json);
    const negative = await call('PUT', `/v1/cart/items/${pid}`, { token, body: { quantity: '-1' } });
    check('negative quantity refused (422)', negative.status === 422, negative.json);
    const word = await call('PUT', `/v1/cart/items/${pid}`, { token, body: { quantity: 'two' } });
    check('non-number quantity refused (422)', word.status === 422, word.json);
    const ghost = await call('PUT', '/v1/cart/items/999999999', { token, body: { quantity: '1' } });
    check('unknown product refused (404)', ghost.status === 404, ghost.json);
    if (loose) {
      const looseAdd = await call('PUT', `/v1/cart/items/${loose.id}`, { token, body: { quantity: loose.minOrderQty } });
      check(`loose item by weight (${loose.minOrderQty} ${loose.unit})`, looseAdd.status === 200, looseAdd.json);
      await call('DELETE', `/v1/cart/items/${loose.id}`, { token });
    }
    await call('PUT', `/v1/cart/items/${pid}`, { token, body: { quantity: '2' } });
    const remove = await call('PUT', `/v1/cart/items/${pid}`, { token, body: { quantity: '0' } });
    const gone = !(remove.json.cart?.items as Json[] | undefined)?.some((l) => l.productId === pid);
    check('quantity 0 removes the line', remove.status === 200 && gone, remove.json);

    console.log('\nAddresses & delivery area');
    const badPin = await call('POST', '/v1/me/addresses', { token, body: { recipientName: 'Test', phone: '9999999999', pincode: '12345', line1: 'x', city: 'Trichy' } });
    check('invalid pincode refused (422)', badPin.status === 422, badPin.json);
    const badPhone = await call('POST', '/v1/me/addresses', { token, body: { recipientName: 'Test', phone: '123', pincode: '620102', line1: 'x', city: 'Trichy' } });
    check('invalid phone refused (422)', badPhone.status === 422, badPhone.json);
    const far = await call('POST', '/v1/me/addresses', {
      token,
      body: { label: `smoke-${tag}`, recipientName: 'Smoke Far', phone: '9999999999', pincode: '600001', line1: 'Test street', city: 'Chennai', latitude: 13.0827, longitude: 80.2707 },
    });
    if (far.json.address?.id) createdAddresses.push(far.json.address.id);
    check('far-away address saved (Chennai)', far.status === 201, far.json);
    const addrList = await call('GET', '/v1/me/addresses', { token });
    const home1 = (addrList.json.addresses as Json[]).find((a) => a.serviceable !== false && a.id !== far.json.address?.id);
    check('demo account has a deliverable Trichy address', Boolean(home1), addrList.json);
    await call('PUT', `/v1/cart/items/${pid}`, { token, body: { quantity: '1' } });
    const farQuote = far.json.address?.id ? await call('POST', '/v1/checkout/quote', { token, body: { addressId: far.json.address.id } }) : null;
    const farBlocked = farQuote?.json.quote?.canPlaceOrder === false && (farQuote.json.quote.blockers as Json[]).some((b) => b.reason === 'address_not_serviceable');
    check('quote says Chennai is outside the delivery area', farBlocked, farQuote?.json.quote?.blockers);
    const farOrder = await call('POST', '/v1/orders', {
      token,
      body: { addressId: far.json.address?.id, paymentMethod: 'cod', idempotencyKey: `shop-${tag}-far`, expectedTotal: farQuote?.json.quote?.totals?.total ?? '1.00' },
    });
    if (farOrder.json.order?.id) await silence(farOrder.json.order.id);
    check('placing an order to Chennai is refused', farOrder.status === 409 && !farOrder.json.order, farOrder.json);
    const pinOk = await call('GET', '/v1/delivery/pincodes/620102');
    check('shop pincode 620102 checked', pinOk.status === 200, pinOk.json);

    console.log('\nQuote, free delivery & placing orders');
    const small = await call('POST', '/v1/checkout/quote', { token, body: { addressId: home1!.id } });
    const smallTotals = small.json.quote?.totals as Json | undefined;
    check('quote for a small order', small.status === 200 && Boolean(smallTotals), small.json);
    const fee = Number(smallTotals?.deliveryFee ?? smallTotals?.delivery ?? NaN);
    check('delivery charge below ₹999', Number(smallTotals?.subtotal ?? 0) >= 999 || fee > 0, smallTotals);
    // Enough of the product to pass ₹999 (within its limit), for the free-delivery rule.
    const price = Number(packed!.sellingPrice);
    const needed = Math.ceil(999 / price);
    let bigTotals: Json | undefined;
    if (needed <= Number(packed!.maxPurchasableQty)) {
      await call('PUT', `/v1/cart/items/${pid}`, { token, body: { quantity: String(needed) } });
      const big = await call('POST', '/v1/checkout/quote', { token, body: { addressId: home1!.id } });
      bigTotals = big.json.quote?.totals as Json | undefined;
      check(`free delivery at ₹${(needed * price).toFixed(0)} (≥ ₹999)`, Number(bigTotals?.deliveryFee ?? bigTotals?.delivery ?? -1) === 0, bigTotals);
      await call('PUT', `/v1/cart/items/${pid}`, { token, body: { quantity: '1' } });
    } else console.log('  – free-delivery check skipped (purchase limit too low for ₹999)');

    const quote = await call('POST', '/v1/checkout/quote', { token, body: { addressId: home1!.id } });
    const total = quote.json.quote?.totals?.total as string;
    const wrongTotal = await call('POST', '/v1/orders', { token, body: { addressId: home1!.id, paymentMethod: 'cod', idempotencyKey: `shop-${tag}-x`, expectedTotal: (Number(total) - 1).toFixed(2) } });
    check('changed total refused (no surprise charges)', wrongTotal.status === 409, wrongTotal.json);
    const key = `shop-${tag}-1`;
    const first = await call('POST', '/v1/orders', { token, body: { addressId: home1!.id, paymentMethod: 'cod', idempotencyKey: key, expectedTotal: total } });
    if (first.json.order?.id) await silence(first.json.order.id);
    check('COD order placed', first.status === 201, first.json);
    const again = await call('POST', '/v1/orders', { token, body: { addressId: home1!.id, paymentMethod: 'cod', idempotencyKey: key, expectedTotal: total } });
    if (again.json.order?.id && again.json.order.id !== first.json.order?.id) await silence(again.json.order.id);
    check('double tap → the same order, not two', again.json.order?.id === first.json.order?.id, again.json);
    const cartAfter = await call('GET', '/v1/cart', { token });
    check('cart emptied after ordering', ((cartAfter.json.cart?.items as Json[] | undefined) ?? []).length === 0, cartAfter.json);
    const mine = await call('GET', '/v1/orders', { token });
    check('order in "My orders"', (mine.json.orders as Json[] | undefined)?.some((o) => o.id === first.json.order?.id) === true, mine.json);
    const [{ reserved: heldBefore } = { reserved: '0' }] = await db.select({ reserved: products.reservedQuantity }).from(products).where(eq(products.id, pid));
    const cancel = await call('POST', `/v1/orders/${first.json.order?.id}/cancel`, { token, body: { reason: 'Smoke test' } });
    check('customer cancels before packing', cancel.status === 200 && cancel.json.order?.status === 'cancelled', cancel.json);
    const [{ reserved: heldAfter } = { reserved: '0' }] = await db.select({ reserved: products.reservedQuantity }).from(products).where(eq(products.id, pid));
    check('stock hold released on cancel', Number(heldAfter) < Number(heldBefore), { heldBefore, heldAfter });
    const cancelAgain = await call('POST', `/v1/orders/${first.json.order?.id}/cancel`, { token, body: { reason: 'again' } });
    check('cancelling twice is refused or harmless', cancelAgain.status < 500, cancelAgain.json);

    console.log('\nOnline payment (Razorpay order only — never paid)');
    await call('PUT', `/v1/cart/items/${pid}`, { token, body: { quantity: '1' } });
    const q2 = await call('POST', '/v1/checkout/quote', { token, body: { addressId: home1!.id } });
    const online = await call('POST', '/v1/orders', { token, body: { addressId: home1!.id, paymentMethod: 'online', idempotencyKey: `shop-${tag}-2`, expectedTotal: q2.json.quote?.totals?.total } });
    if (online.json.order?.id) await silence(online.json.order.id);
    if (online.status === 409 && /online/i.test(JSON.stringify(online.json))) console.log('  – online payments are switched off in Store settings');
    else {
      check('online order created (waiting for payment)', online.status === 201, online.json);
      const pay = await call('POST', `/v1/orders/${online.json.order?.id}/payment`, { token });
      const keyId = String(pay.json.keyId ?? pay.json.payment?.keyId ?? '');
      check('Razorpay checkout prepared', pay.status === 200 || pay.status === 201, pay.json);
      console.log(`    (this local run uses ${keyId.startsWith('rzp_live') ? 'LIVE' : keyId.startsWith('rzp_test') ? 'TEST' : 'unknown'} Razorpay keys)`);
      const fake = await call('POST', `/v1/orders/${online.json.order?.id}/payment/confirm`, {
        token,
        body: { razorpayOrderId: 'order_fake', razorpayPaymentId: 'pay_fake', razorpaySignature: 'f'.repeat(64) },
      });
      check('forged payment confirmation refused', fake.status >= 400 && fake.status < 500, fake.json);
      const stillUnpaid = await call('GET', `/v1/orders/${online.json.order?.id}`, { token });
      check('order still unpaid after the forged confirmation', stillUnpaid.json.order?.paymentStatus !== 'paid', stillUnpaid.json.order);
    }
  } finally {
    const leftovers = createdOrders.length ? await db.select({ id: orders.id, status: orders.orderStatus }).from(orders).where(inArray(orders.id, createdOrders)) : [];
    const holding = leftovers.filter((o) => !['delivered', 'cancelled', 'payment_failed'].includes(o.status)).map((o) => o.id);
    if (holding.length) await ordersRepository.releaseForOrders(db, holding);
    if (createdOrders.length) {
      await db.delete(refunds).where(inArray(refunds.orderId, createdOrders));
      await db.delete(payments).where(inArray(payments.orderId, createdOrders));
      await db.delete(orders).where(inArray(orders.id, createdOrders));
    }
    if (createdAddresses.length) await db.delete(addresses).where(inArray(addresses.id, createdAddresses));
    if (demo) {
      await db.delete(cartItems).where(eq(cartItems.userId, demo.id));
      if (savedCart.length) await db.insert(cartItems).values(savedCart);
    }
    console.log(`\nCleaned up ${createdOrders.length} test order(s), ${createdAddresses.length} address(es); demo cart restored.`);
    server.close();
    await closeDb();
  }

  console.log(failures === 0 ? '\n🎉 Shopping works end to end.' : `\n❌ ${failures} check(s) failed.`);
  process.exitCode = failures === 0 ? 0 : 1;
}

main().catch((error: unknown) => {
  console.error('❌ smoke test crashed:', error);
  process.exitCode = 1;
});
