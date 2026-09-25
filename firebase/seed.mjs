import {initializeApp, applicationDefault, deleteApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore, Timestamp, GeoPoint} from 'firebase-admin/firestore';
import {pathToFileURL} from 'node:url';

export const demoAccounts = [
  {key: 'admin', email: 'admin@harvesthub.app', password: 'Admin@123', role: 'admin',
    name: 'HarvestHub Administrator', phone: '0901000001',
    address: 'HarvestHub office, District 1, Ho Chi Minh City'},
  {key: 'farmer1', email: 'farmer1@harvesthub.app', password: 'Farmer@123', role: 'farmer',
    name: 'Minh Lam Nguyen', phone: '0903123481', address: '12 Ho Tung Mau, Ward 3, Da Lat',
    businessName: 'Green Garden Da Lat', area: 'Da Lat',
    description: 'Highland vegetables and fruit, harvested early in the morning in Da Lat.'},
  {key: 'farmer2', email: 'farmer2@harvesthub.app', password: 'Farmer@123', role: 'farmer',
    name: 'Thi Hoa Tran', phone: '0918234590', address: 'Hamlet 4, Van Hoa commune, Ba Vi, Hanoi',
    businessName: 'Ba Vi Dairy Farm', area: 'Ba Vi',
    description: 'Fresh milk, free-range eggs, and produce from the Ba Vi area.'},
  {key: 'customer', email: 'customer@harvesthub.app', password: 'Customer@123', role: 'customer',
    name: 'Thu Ha Le', phone: '0987123456', address: '45 Nguyen Van Cu, District 5, Ho Chi Minh City'},
];
// Approximate demo pickup points, not verified trading addresses.
export const pickupLocations = {
  farmer1: {latitude: 11.9404, longitude: 108.4583, address: 'Demo pickup point, Da Lat'},
  farmer2: {latitude: 21.0805, longitude: 105.3956, address: 'Demo pickup point, Ba Vi'},
};
const pickupFields = (key) => {
  const point = pickupLocations[key];
  return {pickupLocation: new GeoPoint(point.latitude, point.longitude), pickupAddress: point.address};
};

// Only backfill demo farmers without a location; never reset products or accounts.
export async function seedPickupLocations(app) {
  const db = getFirestore(app);
  const auth = getAuth(app);
  let updated = 0;
  for (const account of demoAccounts.filter((a) => a.role === 'farmer')) {
    const user = await auth.getUserByEmail(account.email);
    const didUpdate = await db.runTransaction(async (tx) => {
      const profile = await tx.get(db.doc('users/' + user.uid));
      const ref = db.doc('farmers/' + user.uid);
      const farmer = await tx.get(ref);
      if (profile.data()?.role !== 'farmer' || !farmer.exists) {
        throw new Error('Missing demo farmer profile: ' + account.email);
      }
      if (farmer.data().pickupLocation != null) return false;
      tx.update(ref, pickupFields(account.key));
      return true;
    });
    if (didUpdate) updated++;
  }
  return {updated};
}

export const categories = [
  ['vegetables', 'Vegetables'],
  ['fruits', 'Fruit'],
  ['dairy', 'Dairy & eggs'],
  ['grains', 'Grains'],
  ['herbs', 'Herbs'],
  ['organic', 'Organic'],
];
// Public Unsplash image URLs. No images are redistributed in the repository.
const image = (id) => 'https://images.unsplash.com/' + id + '?auto=format&fit=crop&w=800&q=80';
const pickup = 'Pick up at the stall in your chosen time slot.';
export const products = [
  {id: 'tomato', farmer: 'farmer1', name: 'Cherry tomatoes', categoryId: 'vegetables', price: 35000, unit: 'kg', stockQty: 30,
    image: image('photo-1546094096-0df4bcaaa337'),
    description: 'Vine-ripened cherry tomatoes, picked in the morning in Da Lat. For salads and eating fresh. ' + pickup},
  {id: 'tomato-ba-vi', farmer: 'farmer2', name: 'Cherry tomatoes', categoryId: 'vegetables', price: 32000, unit: 'kg', stockQty: 24,
    image: image('photo-1592924357228-91a4daadcfea'),
    description: 'Fresh cherry tomatoes from Ba Vi, sold by the kilogram. ' + pickup},
  {id: 'greens', farmer: 'farmer1', name: 'Bok choy', categoryId: 'vegetables', price: 18000, unit: 'bunch', stockQty: 40,
    image: image('photo-1540420773420-3366772f4999'),
    description: 'Young bok choy, about 400 g a bunch. ' + pickup},
  {id: 'apple', farmer: 'farmer1', name: 'Fuji apples', categoryId: 'fruits', price: 55000, unit: 'kg', stockQty: 25,
    image: image('photo-1560806887-1e4cd0b6cbd6'),
    description: 'Crisp, lightly sweet Fuji apples. Keep cool. ' + pickup},
  {id: 'basil', farmer: 'farmer1', name: 'Basil', categoryId: 'herbs', price: 8000, unit: 'bunch', stockQty: 50,
    image: image('photo-1618375569909-3c8616cf7733'),
    description: 'Fragrant basil cut the same day. For pho, noodles, and salads. ' + pickup},
  {id: 'milk', farmer: 'farmer2', name: 'Bottled fresh milk', categoryId: 'dairy', price: 32000, unit: 'bottle', stockQty: 20,
    image: image('photo-1563636619-e9143da7973b'),
    description: 'Pasteurized fresh milk, 900 ml bottle. Keep refrigerated. ' + pickup},
  {id: 'eggs', farmer: 'farmer2', name: 'Free-range eggs', categoryId: 'dairy', price: 45000, unit: 'box', stockQty: 15,
    image: image('photo-1518569656558-1f25e69d93d7'),
    description: 'Free-range eggs, box of 10. ' + pickup},
  {id: 'banana', farmer: 'farmer2', name: 'Saba bananas', categoryId: 'fruits', price: 25000, unit: 'bunch', stockQty: 18,
    image: image('photo-1571771894821-ce9b6c11b08e'),
    description: 'Tree-ripened Saba bananas, about 1 kg a bunch. ' + pickup},
  {id: 'rice', farmer: 'farmer2', name: 'ST25 rice', categoryId: 'grains', price: 28000, unit: 'kg', stockQty: 100,
    image: image('photo-1586201375761-83865001e31c'),
    description: 'Soft, lightly fragrant ST25 rice, sold by the kilogram. ' + pickup},
  {id: 'water-spinach', farmer: 'farmer1', name: 'Organic water spinach', categoryId: 'organic', price: 15000, unit: 'bunch', stockQty: 35,
    image: image('photo-1576045057995-568f588f82fb'),
    description: 'Organic water spinach, about 400 g a bunch, from Green Garden Da Lat. ' + pickup},
  {id: 'carrots', farmer: 'farmer1', name: 'Organic carrots', categoryId: 'organic', price: 22000, unit: 'kg', stockQty: 28,
    image: image('photo-1598170845058-32b9d6a5da37'),
    description: 'Organic carrots, sold by the kilogram, from Green Garden Da Lat. ' + pickup},
];

export async function seedDemo(app, {refresh = false} = {}) {
  const db = getFirestore(app);
  const auth = getAuth(app);
  if (!refresh && (await db.doc('categories/fruits').get()).exists) {
    return {skipped: true, reason: 'categories/fruits already exists'};
  }
  const users = new Map();
  for (const account of demoAccounts) {
    let record;
    try { record = await auth.getUserByEmail(account.email); }
    catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
      record = await auth.createUser({email: account.email, password: account.password, displayName: account.name});
    }
    if (refresh) await auth.updateUser(record.uid, {displayName: account.name});
    const existing = await db.doc('users/' + record.uid).get();
    if (existing.exists && existing.data().role !== account.role) {
      throw new Error('Existing demo email has another role: ' + account.email);
    }
    users.set(account.key, {account, uid: record.uid, exists: existing.exists});
  }
  const now = Timestamp.now();
  // The marker category and all Firestore seed documents commit together.
  // A retried seed reuses Auth users but never resets existing passwords.
  // Refresh rewrites English display fields and keeps stock plus stockMutation.
  await db.runTransaction(async (tx) => {
    const marker = await tx.get(db.doc('categories/fruits'));
    if (!refresh && marker.exists) return;
    const existingProducts = [];
    for (const product of products) {
      existingProducts.push(await tx.get(db.doc('products/seed-' + product.id)));
    }
    for (const {account, uid, exists} of users.values()) {
      const userRef = db.doc('users/' + uid);
      if (!exists) {
        tx.set(userRef, {name: account.name, email: account.email, phone: account.phone,
          address: account.address, role: account.role, isActive: true, createdAt: now});
      } else if (refresh) {
        tx.set(userRef, {name: account.name, phone: account.phone, address: account.address}, {merge: true});
      }
      if (account.role === 'farmer') {
        const farmerRef = db.doc('farmers/' + uid);
        const profile = {userId: uid, businessName: account.businessName, description: account.description,
          area: account.area, rating: 5, isActive: true};
        if (refresh) tx.set(farmerRef, profile, {merge: true});
        else tx.set(farmerRef, {...profile, ...pickupFields(account.key), createdAt: now});
      }
    }
    categories.forEach(([id, name], i) => tx.set(db.doc('categories/' + id),
      {name, imageUrl: '', sortOrder: i + 1, isActive: true}));
    products.forEach((product, index) => {
      const farmer = users.get(product.farmer);
      const existing = existingProducts[index];
      const data = {farmerId: farmer.uid, farmerName: farmer.account.businessName, name: product.name,
        categoryId: product.categoryId, description: product.description, price: product.price, unit: product.unit,
        stockQty: product.stockQty, imageUrl: product.image, isActive: true, createdAt: now, updatedAt: now};
      if (existing.exists) {
        const previous = existing.data();
        data.stockQty = previous.stockQty;
        data.createdAt = previous.createdAt;
        if (previous.stockMutation) data.stockMutation = previous.stockMutation;
      }
      tx.set(db.doc('products/seed-' + product.id), data);
    });
  });
  return {skipped: false, users: users.size, categories: categories.length, products: products.length};
}

async function main() {
  const args = process.argv.slice(2);
  const emulator = args.includes('--emulator');
  const refresh = args.includes('--refresh');
  const projectIndex = args.indexOf('--project');
  const projectId = emulator ? 'demo-harvesthub' : (projectIndex >= 0 ? args[projectIndex + 1] : undefined);
  if (!projectId || (!emulator && !args.includes('--confirm-demo-project'))) {
    throw new Error('Use --emulator, or --project YOUR_PROJECT_ID --confirm-demo-project with GOOGLE_APPLICATION_CREDENTIALS for an authorized demo project.');
  }
  if (emulator) {
    process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
    process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8180';
  } else if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error('Remove emulator environment variables before using --project.');
  }
  const app = initializeApp({projectId, ...(emulator ? {} : {credential: applicationDefault()})}, 'harvesthub-seed');
  try { console.log(JSON.stringify(await (args.includes('--locations-only') ? seedPickupLocations(app) : seedDemo(app, {refresh})), null, 2)); }
  finally { await deleteApp(app); }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1; });
}
