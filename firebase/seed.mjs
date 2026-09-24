import {initializeApp, applicationDefault, deleteApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {pathToFileURL} from 'node:url';

export const demoAccounts = [
  {key: 'admin', email: 'admin@harvesthub.app', password: 'Admin@123', role: 'admin', name: 'Quản trị HarvestHub'},
  {key: 'farmer1', email: 'farmer1@harvesthub.app', password: 'Farmer@123', role: 'farmer', name: 'Nông dân Đà Lạt',
    businessName: 'Vườn Xanh Đà Lạt', area: 'Đà Lạt'},
  {key: 'farmer2', email: 'farmer2@harvesthub.app', password: 'Farmer@123', role: 'farmer', name: 'Nông dân Ba Vì',
    businessName: 'Trại Sữa Ba Vì', area: 'Ba Vì'},
  {key: 'customer', email: 'customer@harvesthub.app', password: 'Customer@123', role: 'customer', name: 'Khách hàng demo'},
];
const categories = [
  ['vegetables','Rau củ'], ['fruits','Trái cây'], ['dairy','Sữa & trứng'],
  ['grains','Ngũ cốc'], ['herbs','Rau thơm'], ['organic','Hữu cơ'],
];
// Public Unsplash image URLs. No images are redistributed in the repository.
const image = (id) => 'https://images.unsplash.com/' + id + '?auto=format&fit=crop&w=800&q=80';
const products = [
  ['tomato','farmer1','Cà chua bi','vegetables',35000,'kg',30,image('photo-1546094096-0df4bcaaa337')],
  ['greens','farmer1','Cải ngọt','vegetables',18000,'bó',40,image('photo-1540420773420-3366772f4999')],
  ['apple','farmer1','Táo Fuji','fruits',55000,'kg',25,image('photo-1560806887-1e4cd0b6cbd6')],
  ['basil','farmer1','Húng quế','herbs',8000,'bó',50,image('photo-1618375569909-3c8616cf7733')],
  ['milk','farmer2','Sữa tươi chai','dairy',32000,'chai',20,image('photo-1563636619-e9143da7973b')],
  ['eggs','farmer2','Trứng gà ta','dairy',45000,'vỉ',15,image('photo-1518569656558-1f25e69d93d7')],
  ['banana','farmer2','Chuối sứ','fruits',25000,'nải',18,image('photo-1571771894821-ce9b6c11b08e')],
  ['rice','farmer2','Gạo ST25','grains',28000,'kg',100,image('photo-1586201375761-83865001e31c')],
];

export async function seedDemo(app) {
  const db = getFirestore(app);
  const auth = getAuth(app);
  if ((await db.doc('categories/fruits').get()).exists) {
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
    const existing = await db.doc('users/' + record.uid).get();
    if (existing.exists && existing.data().role !== account.role) {
      throw new Error('Existing demo email has another role: ' + account.email);
    }
    users.set(account.key, {account, uid: record.uid, exists: existing.exists});
  }
  const now = Timestamp.now();
  // The marker category and all Firestore seed documents commit together.
  // A retried seed reuses Auth users but never resets existing passwords.
  await db.runTransaction(async (tx) => {
    const marker = await tx.get(db.doc('categories/fruits'));
    if (marker.exists) return;
    for (const {account, uid, exists} of users.values()) {
      if (!exists) tx.set(db.doc('users/' + uid), {name: account.name, email: account.email,
        phone: '0900000000', address: account.area ?? 'Điểm nhận HarvestHub',
        role: account.role, isActive: true, createdAt: now});
      if (account.role === 'farmer') tx.set(db.doc('farmers/' + uid), {
        userId: uid, businessName: account.businessName, description: 'Nông sản địa phương được chọn lọc mỗi ngày.',
        area: account.area, rating: 5, isActive: true, createdAt: now});
    }
    categories.forEach(([id, name], i) => tx.set(db.doc('categories/' + id),
      {name, imageUrl: '', sortOrder: i + 1, isActive: true}));
    for (const [id, key, name, categoryId, price, unit, stockQty, imageUrl] of products) {
      const farmer = users.get(key);
      tx.set(db.doc('products/seed-' + id), {farmerId: farmer.uid, farmerName: farmer.account.businessName,
        name, categoryId, description: name + ' từ ' + farmer.account.businessName + '. Nhận tại điểm bán theo khung giờ đã chọn.',
        price, unit, stockQty, imageUrl, isActive: true, createdAt: now, updatedAt: now});
    }
  });
  return {skipped: false, users: users.size, categories: categories.length, products: products.length};
}

async function main() {
  const args = process.argv.slice(2);
  const emulator = args.includes('--emulator');
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
  try { console.log(JSON.stringify(await seedDemo(app), null, 2)); }
  finally { await deleteApp(app); }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1; });
}
