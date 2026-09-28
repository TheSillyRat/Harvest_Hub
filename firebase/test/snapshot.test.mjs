import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {test} from 'node:test';

const snapshot = JSON.parse(await readFile(new URL('../data/catalog_snapshot.json', import.meta.url), 'utf8'));

test('catalog snapshot contains demo data with valid references', () => {
  assert.ok(snapshot.categories.length > 0);
  assert.ok(snapshot.farmers.length > 0);
  assert.ok(snapshot.products.length > 0);
  const farmerIds = new Set(snapshot.farmers.map((farmer) => farmer.id));
  const categoryIds = new Set(snapshot.categories.map((category) => category.id));
  const productIds = new Set(snapshot.products.map((product) => product.id));

  for (const farmer of snapshot.farmers) {
    assert.match(farmer.user.email.stringValue, /@harvesthub\.app$/);
  }
  for (const product of snapshot.products) {
    assert.ok(farmerIds.has(product.fields.farmerId.stringValue));
    assert.ok(categoryIds.has(product.fields.categoryId.stringValue));
    assert.equal('stockMutation' in product.fields, false);
  }
  for (const review of snapshot.reviews) {
    assert.ok(productIds.has(review.productId));
    assert.equal(review.fields.isDemo.booleanValue, true);
  }
  for (const relation of snapshot.farmerCategories) {
    assert.ok(farmerIds.has(relation.fields.farmerId.stringValue));
    assert.ok(categoryIds.has(relation.fields.categoryId.stringValue));
  }
  function inspect(value) {
    if (Array.isArray(value)) return value.forEach(inspect);
    if (value && typeof value === 'object') {
      for (const [key, item] of Object.entries(value)) {
        assert.equal(/^(apiKey|password|token|secret)$/i.test(key), false);
        inspect(item);
      }
    } else if (typeof value === 'string' && !value.startsWith('data:image/')) {
      assert.equal(value.includes('AIza'), false);
    }
  }
  inspect(snapshot);
});

test('sample text and review tags are English text without emoji', () => {
  function inspect(value) {
    if (Array.isArray(value)) return value.forEach(inspect);
    if (value && typeof value === 'object') {
      for (const [key, item] of Object.entries(value)) {
        if (key === 'stringValue' && typeof item === 'string' && !item.startsWith('data:image/')) {
          assert.equal([...item].some((character) => character.codePointAt(0) > 127), false,
            `Non-English character in: ${item.slice(0, 80)}`);
        } else {
          inspect(item);
        }
      }
    }
  }
  inspect(snapshot);
  const romanizedGloss = /\b(?:Rau Muong|Kho Qua|Cai Xanh|Chuoi Su|Cam Sanh|Dau Xanh|Hung Que|Hung Lui|Ngo Ri|Ngo Gai|La Dua|Thi La|Dau Ha Lan|Da Xanh)\b/i;
  for (const product of snapshot.products) {
    assert.doesNotMatch(product.fields.name.stringValue, romanizedGloss);
  }
  for (const review of snapshot.reviews) {
    for (const tag of review.fields.tags?.arrayValue?.values ?? []) {
      assert.match(tag.stringValue, /^[\x20-\x7e]+$/);
    }
  }
});
