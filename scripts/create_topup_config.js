const admin = require('firebase-admin');

async function main() {
  const projectId = process.env.PROJECT_ID || 'nigergram';

  // Initialize with ADC (GOOGLE_APPLICATION_CREDENTIALS) — workflow sets this
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId,
    });
  }

  const db = admin.firestore();
  const docRef = db.collection('config').doc('topup');

  const doc = await docRef.get();
  if (doc.exists) {
    console.log('/config/topup already exists. No changes made.');
    console.log('Document data:', JSON.stringify(doc.data(), null, 2));
    process.exit(0);
  }

  const data = {
    accountNumber: '',
    accountName: '',
    provider: '',
    nairaPerCent: 1,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await docRef.set(data);
  console.log('Created /config/topup with data:', JSON.stringify(data, null, 2));
}

main().catch(err => {
  console.error('Error creating /config/topup:', err);
  process.exit(1);
});
