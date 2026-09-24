import {test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp as initializeAdminApp, deleteApp as deleteAdminApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {initializeApp, deleteApp} from 'firebase/app';
import {getAuth, connectAuthEmulator, signInWithEmailAndPassword, signOut} from 'firebase/auth';
import {seedDemo, demoAccounts} from '../seed.mjs';

test('seed creates 4 working logins, 6 categories, 8 products, and does not reset stock on rerun', async () => {
  const projectId = 'demo-harvesthub';
  await fetch('http://' + process.env.FIRESTORE_EMULATOR_HOST + '/emulator/v1/projects/' + projectId + '/databases/(default)/documents', {method: 'DELETE'});
  const admin = initializeAdminApp({projectId}, 'seed-test');
  const client = initializeApp({projectId, apiKey: 'demo-key'}, 'seed-login-test');
  const auth = getAuth(client);
  connectAuthEmulator(auth, 'http://' + process.env.FIREBASE_AUTH_EMULATOR_HOST, {disableWarnings: true});
  try {
    const result = await seedDemo(admin);
    assert.deepEqual(result, {skipped: false, users: 4, categories: 6, products: 8});
    const db = getFirestore(admin);
    for (const account of demoAccounts) {
      const credential = await signInWithEmailAndPassword(auth, account.email, account.password);
      const doc = await db.doc('users/' + credential.user.uid).get();
      assert.equal(doc.data().role, account.role);
      if (account.role === 'farmer') {
        const farmer = await db.doc('farmers/' + credential.user.uid).get();
        assert.equal(farmer.data().businessName, account.businessName);
      }
      await signOut(auth);
    }
    await db.doc('products/seed-tomato').update({stockQty: 7});
    assert.equal((await seedDemo(admin)).skipped, true);
    assert.equal((await db.doc('products/seed-tomato').get()).data().stockQty, 7);
    assert.equal((await db.collection('products').get()).size, 8);
    assert.equal((await db.collection('categories').get()).size, 6);
    assert.equal((await db.collection('users').get()).size, 4);
  } finally {
    await deleteApp(client);
    await deleteAdminApp(admin);
  }
});
