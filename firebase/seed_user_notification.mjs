import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

async function seedUserNotification() {
  const args = process.argv.slice(2);
  const emulator = args.includes('--emulator');
  const email = 'sang12@gmail.com';

  if (emulator) {
    process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
    process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8180';
  }

  const app = initializeApp(
    { projectId: 'demo-harvesthub', ...(emulator ? {} : { credential: applicationDefault() }) },
    'seed-user-notif'
  );

  const db = getFirestore(app);
  const auth = getAuth(app);

  let userId = '';

  try {
    const userRecord = await auth.getUserByEmail(email);
    userId = userRecord.uid;
    console.log(`Found Auth user ${email} with UID: ${userId}`);
  } catch (_) {
    console.log(`User ${email} not found in Auth emulator/project. Searching Firestore users collection...`);
  }

  if (!userId) {
    const snap = await db.collection('users').where('email', '==', email).get();
    if (!snap.empty) {
      userId = snap.docs[0].id;
      console.log(`Found Firestore user ${email} with ID: ${userId}`);
    }
  }

  if (!userId) {
    userId = 'user_sang12_demo';
    console.log(`Could not find existing user ${email}. Using fallback UID: ${userId}`);
  }

  const notifId = 'notif_sang12_' + Date.now();
  const notificationData = {
    userId: userId,
    title: '🌱 Order Status Update (#ORD-9912)',
    body: 'Your fresh produce order #ORD-9912 has been confirmed by Da Lat Organic Farm and is ready for pickup!',
    type: 'order_status',
    targetId: 'ORD-9912',
    isRead: false,
    createdAt: Timestamp.now(),
  };

  await db.collection('notifications').doc(notifId).set(notificationData);
  console.log(`✅ Successfully seeded notification ${notifId} for user ${email} (${userId}):`, notificationData);
}

seedUserNotification().catch((err) => {
  console.error('Error seeding notification:', err);
  process.exit(1);
});
