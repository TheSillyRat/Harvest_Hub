import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {seedSnapshot} from '../seed_snapshot.mjs';

const catalog = JSON.parse(await readFile(new URL('../data/catalog_snapshot.json', import.meta.url), 'utf8'));

test('snapshot seed creates demo accounts and preserves existing stock on rerun', async () => {
  const projectId = 'demo-harvesthub';
  const review = catalog.reviews[0];
  const product = catalog.products.find((item) => item.id === review.productId);
  const farmer = catalog.farmers.find((item) => item.id === product.fields.farmerId.stringValue);
  const category = catalog.categories.find((item) => item.id === product.fields.categoryId.stringValue);
  const relation = catalog.farmerCategories.find((item) =>
    item.fields.farmerId.stringValue === farmer.id &&
    item.fields.categoryId.stringValue === category.id);
  assert.ok(relation);
  const sample = {categories: [category], farmers: [farmer], products: [product],
    farmerCategories: [relation], reviews: [review]};

  const app = initializeApp({projectId}, 'snapshot-seed-test');
  try {
    const db = getFirestore(app);
    const auth = getAuth(app);
    const first = await seedSnapshot(app, sample);
    assert.deepEqual(first, {categories: 1, farmers: 1, products: 1, farmerCategories: 1, reviews: 1});
    for (const email of ['admin@harvesthub.app', 'customer@harvesthub.app',
      farmer.user.email.stringValue]) {
      assert.ok((await auth.getUserByEmail(email)).uid);
    }

    await db.collection('products').doc(product.id).update({stockQty: 7});
    const second = await seedSnapshot(app, sample);
    assert.deepEqual(second, {categories: 0, farmers: 0, products: 0, farmerCategories: 0, reviews: 0});
    assert.equal((await db.collection('products').doc(product.id).get()).data().stockQty, 7);
  } finally {
    await deleteApp(app);
  }
});
