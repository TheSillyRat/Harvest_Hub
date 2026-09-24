import {readFile} from 'node:fs/promises';
import {before, after, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, setDoc, updateDoc, getDoc, getDocs, collection, query, where, writeBatch, runTransaction, Timestamp} from 'firebase/firestore';
import {ref, uploadBytes} from 'firebase/storage';

let env;
const now = Timestamp.now();
const user = (role, name = role) => ({name, email: name + '@harvesthub.app', phone: '0900000000',
  address: 'Đà Lạt', role, isActive: true, createdAt: now});
const product = (id, stockQty = 10, farmerId = 'farmer') => ({farmerId, farmerName: 'Vườn Xanh',
  name: id, categoryId: 'vegetables', description: 'Tươi', price: 35000, unit: 'kg', stockQty,
  imageUrl: '', isActive: true, createdAt: now, updatedAt: now});
const dbFor = (uid) => env.authenticatedContext(uid, {email: uid + '@harvesthub.app'}).firestore();
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-harvesthub',
    firestore: {rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8')},
    storage: {rules: await readFile(new URL('../storage.rules', import.meta.url), 'utf8')}});
});
after(async () => { await env?.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const batch = writeBatch(db);
    for (const [uid, role] of [['customer','customer'],['other','customer'],['farmer','farmer'],['farmer2','farmer'],['admin','admin']]) {
      batch.set(doc(db, 'users', uid), user(role, uid));
      if (role === 'farmer') batch.set(doc(db, 'farmers', uid), {userId: uid, businessName: 'Vườn Xanh',
        description: '', area: 'Đà Lạt', rating: 5, isActive: true, createdAt: now});
    }
    for (let i = 0; i < 8; i++) batch.set(doc(db, 'products', 'p' + i), product('p' + i));
    batch.set(doc(db, 'products', 'other-farm'), product('other-farm', 10, 'farmer2'));
    await batch.commit();
  });
});
async function place(db, id = 'order', ids = ['p0'], qty = 3, options = {}) {
  await runTransaction(db, async (tx) => {
    const products = [];
    for (const pid of ids) products.push(await tx.get(doc(db, 'products', pid)));
    const items = products.map((p) => {
      const d = p.data();
      return {productId: p.id, name: d.name, price: d.price, unit: d.unit, imageUrl: d.imageUrl, qty, subtotal: qty * d.price};
    });
    const order = {customerId: 'customer', customerName: 'customer', customerPhone: '0900000000',
      farmerId: 'farmer', farmerName: 'Vườn Xanh', items, address: 'Đà Lạt',
      pickupSlot: 'morning_07_10', pickupDate: now, total: items.reduce((n, i) => n + i.subtotal, 0),
      status: 'Pending', createdAt: now, updatedAt: now, ...options};
    for (let i = 0; i < products.length; i++) tx.update(products[i].ref, {
      stockQty: products[i].data().stockQty - qty, updatedAt: now,
      stockMutation: {orderId: id, itemIndex: i, kind: 'Pending'}});
    tx.set(doc(db, 'orders', id), order);
  });
}
async function cancel(db, id = 'order') {
  await runTransaction(db, async (tx) => {
    const order = await tx.get(doc(db, 'orders', id));
    const products = [];
    for (const item of order.data().items) products.push(await tx.get(doc(db, 'products', item.productId)));
    for (let i = 0; i < products.length; i++) tx.update(products[i].ref, {
      stockQty: products[i].data().stockQty + order.data().items[i].qty,
      stockMutation: {orderId: id, itemIndex: i, kind: 'Cancelled'}, updatedAt: now});
    tx.update(order.ref, {status: 'Cancelled', updatedAt: now});
  });
}

test('customer cannot self-promote, unlock, or create an admin', async () => {
  const db = dbFor('customer');
  await assertFails(updateDoc(doc(db, 'users/customer'), {role: 'admin'}));
  await assertFails(updateDoc(doc(db, 'users/customer'), {isActive: false}));
  await assertFails(setDoc(doc(dbFor('new'), 'users/new'), user('admin', 'new')));
  await assertSucceeds(updateDoc(doc(db, 'users/customer'), {name: 'Khách mới'}));
});
test('registration creates farmer and profile atomically', async () => {
  const db = dbFor('new');
  const batch = writeBatch(db);
  batch.set(doc(db, 'users/new'), user('farmer', 'new'));
  batch.set(doc(db, 'farmers/new'), {userId: 'new', businessName: 'Vườn mới', description: '',
    area: 'Đà Lạt', rating: 5, isActive: true, createdAt: now});
  await assertSucceeds(batch.commit());
});
test('stock deduction, sequential status, cancellation and no double refund', async () => {
  const customer = dbFor('customer'), farmer = dbFor('farmer');
  await assertSucceeds(place(customer));
  assert.equal((await getDoc(doc(customer, 'products/p0'))).data().stockQty, 7);
  await assertFails(updateDoc(doc(customer, 'orders/order'), {status: 'Confirmed'}));
  await assertFails(updateDoc(doc(farmer, 'orders/order'), {status: 'Completed'}));
  await assertSucceeds(updateDoc(doc(farmer, 'orders/order'), {status: 'Confirmed', updatedAt: now}));
  await assertFails(updateDoc(doc(customer, 'orders/order'), {status: 'Cancelled'}));
  await assertSucceeds(cancel(customer));
  assert.equal((await getDoc(doc(customer, 'products/p0'))).data().stockQty, 10);
  await assertFails(cancel(customer));
});
test('ready and completed orders cannot be cancelled', async () => {
  const db = dbFor('farmer');
  await place(dbFor('customer'));
  for (const status of ['Confirmed', 'ReadyForPickup']) await assertSucceeds(updateDoc(doc(db, 'orders/order'), {status, updatedAt: now}));
  await assertFails(cancel(db));
  await assertSucceeds(updateDoc(doc(db, 'orders/order'), {status: 'Completed', updatedAt: now}));
  await assertFails(cancel(dbFor('admin')));
});
test('ownership, private orders and collection queries', async () => {
  await place(dbFor('customer'));
  await assertFails(getDoc(doc(dbFor('other'), 'orders/order')));
  await assertFails(getDoc(doc(dbFor('farmer2'), 'orders/order')));
  await assertSucceeds(getDocs(query(collection(dbFor('customer'), 'orders'), where('customerId', '==', 'customer'))));
  await assertFails(getDocs(collection(dbFor('customer'), 'orders')));
  await assertSucceeds(getDocs(collection(dbFor('admin'), 'orders')));
  await assertFails(updateDoc(doc(dbFor('farmer2'), 'products/p0'), {name: 'Stolen'}));
  await assertFails(updateDoc(doc(dbFor('farmer'), 'products/p0'), {farmerId: 'farmer2'}));
});
test('reject forged total, wrong farmer, negative inventory and direct customer stock edits', async () => {
  const db = dbFor('customer');
  await assertFails(place(db, 'bad-total', ['p0'], 3, {total: 1}));
  await assertFails(place(db, 'wrong-farmer', ['other-farm']));
  await assertFails(place(db, 'overstock', ['p0'], 11));
  await assertFails(updateDoc(doc(db, 'products/p0'), {stockQty: 0}));
  assert.equal((await getDoc(doc(db, 'products/p0'))).data().stockQty, 10);
});
test('8 distinct items pass rules access limits for checkout and refund', async () => {
  const db = dbFor('customer');
  await assertSucceeds(place(db, 'order', Array.from({length: 8}, (_, i) => 'p' + i)));
  await assertSucceeds(cancel(dbFor('farmer')));
  for (let i = 0; i < 8; i++) assert.equal((await getDoc(doc(db, 'products/p' + i))).data().stockQty, 10);
});
test('concurrent buyers cannot oversell', async () => {
  const db = dbFor('customer');
  const results = await Promise.allSettled([place(db, 'race-a', ['p0'], 7), place(db, 'race-b', ['p0'], 7)]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal((await getDoc(doc(db, 'products/p0'))).data().stockQty, 3);
});
test('inactive user blocked; admin cannot lock own account', async () => {
  const admin = dbFor('admin');
  await assertFails(updateDoc(doc(admin, 'users/admin'), {isActive: false}));
  await updateDoc(doc(admin, 'users/customer'), {isActive: false});
  await assertFails(place(dbFor('customer')));
});
test('customer cart is isolated and validates stock', async () => {
  const db = dbFor('customer');
  await assertFails(setDoc(doc(db, 'carts/other/items/p0'), {productId: 'p0', qty: 1}));
  await assertFails(setDoc(doc(db, 'carts/customer/items/p0'), {productId: 'p0', qty: 11}));
  await assertSucceeds(setDoc(doc(db, 'carts/customer/items/p0'), {productId: 'p0', qty: 2}));
});
test('Storage permits only image uploads by the owning farmer', async () => {
  const data = new Uint8Array([255,216,255,217]);
  await assertSucceeds(uploadBytes(ref(env.authenticatedContext('farmer').storage(), 'products/farmer/test.jpg'), data, {contentType: 'image/jpeg'}));
  await assertFails(uploadBytes(ref(env.authenticatedContext('customer').storage(), 'products/customer/test.jpg'), data, {contentType: 'image/jpeg'}));
  await assertFails(uploadBytes(ref(env.authenticatedContext('farmer2').storage(), 'products/farmer/test.jpg'), data, {contentType: 'image/jpeg'}));
  await assertFails(uploadBytes(ref(env.authenticatedContext('farmer').storage(), 'products/farmer/test.txt'), data, {contentType: 'text/plain'}));
});
