import {readFile} from 'node:fs/promises';
import {fileURLToPath, pathToFileURL} from 'node:url';
import path from 'node:path';
import {applicationDefault, deleteApp, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {GeoPoint, getFirestore, Timestamp} from 'firebase-admin/firestore';

const snapshotPath = path.resolve(path.dirname(fileURLToPath(import.meta.url)), 'data/catalog_snapshot.json');
const demoAccounts = [
  {email: 'admin@harvesthub.app', password: 'Admin@123', role: 'admin',
    name: 'HarvestHub Administrator', phone: '0901000001',
    address: 'HarvestHub office, District 1, Ho Chi Minh City'},
  {email: 'customer@harvesthub.app', password: 'Customer@123', role: 'customer',
    name: 'Demo Customer', phone: '0987123456', address: 'Demo pickup location'},
];

function decode(value) {
  if ('nullValue' in value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return Timestamp.fromDate(new Date(value.timestampValue));
  if ('geoPointValue' in value) {
    return new GeoPoint(Number(value.geoPointValue.latitude), Number(value.geoPointValue.longitude));
  }
  if ('arrayValue' in value) return (value.arrayValue.values ?? []).map(decode);
  if ('mapValue' in value) return decodeFields(value.mapValue.fields ?? {});
  if ('bytesValue' in value) return Buffer.from(value.bytesValue, 'base64');
  throw new Error(`Unsupported Firestore value: ${Object.keys(value).join(', ')}`);
}

function decodeFields(fields) {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decode(value)]));
}

async function createIfMissing(ref, data) {
  if ((await ref.get()).exists) return false;
  await ref.create(data);
  return true;
}

async function ensureAccount(auth, db, account, userFields) {
  const email = account.email;
  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    user = await auth.createUser({email, password: account.password, displayName: account.name});
  }
  const fields = userFields ? decodeFields(userFields) : {};
  await createIfMissing(db.collection('users').doc(user.uid), {
    ...fields,
    email,
    name: fields.name ?? account.name,
    phone: fields.phone ?? account.phone ?? '0900000000',
    address: fields.address ?? account.address ?? 'Demo pickup location',
    role: account.role,
    isActive: fields.isActive ?? true,
    createdAt: fields.createdAt ?? Timestamp.now(),
  });
  return user.uid;
}

export async function seedSnapshot(app, snapshot) {
  const db = getFirestore(app);
  const auth = getAuth(app);
  const farmerIds = new Map();
  const counts = {categories: 0, farmers: 0, products: 0, farmerCategories: 0, reviews: 0};

  for (const account of demoAccounts) {
    await ensureAccount(auth, db, account);
  }

  for (const farmer of snapshot.farmers) {
    const user = decodeFields(farmer.user);
    const account = {
      email: user.email, name: user.name ?? 'Demo Farmer',
      phone: user.phone, address: user.address,
      role: 'farmer', password: 'Farmer@123',
    };
    const uid = await ensureAccount(auth, db, account, farmer.user);
    farmerIds.set(farmer.id, uid);
    const profile = decodeFields(farmer.fields);
    profile.userId = uid;
    if (await createIfMissing(db.collection('farmers').doc(uid), profile)) counts.farmers++;
  }

  for (const category of snapshot.categories) {
    if (await createIfMissing(db.collection('categories').doc(category.id), decodeFields(category.fields))) {
      counts.categories++;
    }
  }
  for (const product of snapshot.products) {
    const data = decodeFields(product.fields);
    const uid = farmerIds.get(data.farmerId);
    if (!uid) throw new Error(`Missing demo farmer for product ${product.id}`);
    data.farmerId = uid;
    if (await createIfMissing(db.collection('products').doc(product.id), data)) counts.products++;
  }
  for (const relation of snapshot.farmerCategories) {
    const data = decodeFields(relation.fields);
    data.farmerId = farmerIds.get(data.farmerId);
    if (!data.farmerId) throw new Error(`Missing demo farmer for category ${relation.id}`);
    const id = `${data.farmerId}_${data.categoryId}`;
    if (await createIfMissing(db.collection('farmer_categories').doc(id), data)) {
      counts.farmerCategories++;
    }
  }
  for (const review of snapshot.reviews) {
    const ref = db.collection('products').doc(review.productId).collection('reviews').doc(review.id);
    if (await createIfMissing(ref, decodeFields(review.fields))) counts.reviews++;
  }
  return counts;
}

async function main() {
  const args = process.argv.slice(2);
  const emulator = args.includes('--emulator');
  const projectIndex = args.indexOf('--project');
  const snapshot = JSON.parse(await readFile(snapshotPath, 'utf8'));
  const projectId = emulator ? 'demo-harvesthub' :
    (projectIndex >= 0 ? args[projectIndex + 1] : undefined);
  if (!emulator && (!projectId || !args.includes('--confirm-demo-project'))) {
    throw new Error('Use --emulator, or --project PROJECT_ID --confirm-demo-project with Google application credentials.');
  }
  if (emulator) {
    process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
    process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8180';
  } else if (process.env.FIREBASE_AUTH_EMULATOR_HOST || process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Remove emulator environment variables before writing to a cloud project.');
  }
  const app = initializeApp({projectId, ...(emulator ? {} : {credential: applicationDefault()})}, 'harvesthub-snapshot-seed');
  try {
    const counts = await seedSnapshot(app, snapshot);
    console.log(`Seed complete for ${projectId}: ${JSON.stringify(counts)}`);
  } finally {
    await deleteApp(app);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {console.error(error.message); process.exitCode = 1;});
}
