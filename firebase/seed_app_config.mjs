import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import * as fs from 'node:fs';
import * as path from 'node:path';

async function seedAppConfig() {
  const args = process.argv.slice(2);
  const emulator = args.includes('--emulator');

  let apiKey = '';

  const keyIndex = args.indexOf('--key');
  if (keyIndex >= 0 && args[keyIndex + 1]) {
    apiKey = args[keyIndex + 1].trim();
  }

  if (!apiKey && process.env.GEMINI_API_KEY) {
    apiKey = process.env.GEMINI_API_KEY.trim();
  }

  if (!apiKey) {
    const candidatePaths = [
      path.resolve(process.cwd(), 'gemini_api_key.txt'),
      path.resolve(process.cwd(), '../gemini_api_key.txt'),
      path.resolve(process.cwd(), 'api_key.txt'),
      path.resolve(process.cwd(), '../api_key.txt'),
    ];
    for (const p of candidatePaths) {
      if (fs.existsSync(p)) {
        apiKey = fs.readFileSync(p, 'utf-8').trim();
        if (apiKey) break;
      }
    }
  }

  if (!apiKey) {
    console.error('Error: No Gemini API key provided. Use --key <KEY>, set GEMINI_API_KEY, or place gemini_api_key.txt.');
    process.exit(1);
  }

  if (emulator) {
    process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';
    process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8180';
  }

  const projectIndex = args.indexOf('--project');
  const projectId = emulator
    ? 'demo-harvesthub'
    : (projectIndex >= 0 ? args[projectIndex + 1] : (process.env.FIREBASE_PROJECT_ID || 'harvesthub-c57ec'));

  const app = initializeApp(
    { projectId, ...(emulator ? {} : { credential: applicationDefault() }) },
    'seed-app-config'
  );

  const db = getFirestore(app);

  const configDoc = {
    apiKey: apiKey,
    updatedAt: Timestamp.now(),
    model: 'gemini-2.5-flash',
  };

  await db.collection('app_config').doc('gemini').set(configDoc, { merge: true });
  console.log(`Successfully stored Gemini API config in Firestore: app_config/gemini (project: ${projectId})`);
}

seedAppConfig().catch((err) => {
  console.error('Error seeding app config:', err.message);
  process.exit(1);
});
