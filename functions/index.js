const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });

admin.initializeApp();
const db = admin.firestore();

// Helper: verify Firebase ID token from Authorization header
async function verifyToken(req) {
  const auth = req.get('Authorization') || req.get('authorization');
  if (!auth || !auth.startsWith('Bearer ')) throw { status: 401, message: 'Missing Authorization' };
  const idToken = auth.split('Bearer ')[1];
  try {
    return await admin.auth().verifyIdToken(idToken);
  } catch (e) {
    throw { status: 401, message: 'Invalid token' };
  }
}

// Generate a short payment code, ensure reasonable uniqueness by retrying a few times.
function generatePaymentCode() {
  const digits = Math.floor(Math.random() * 90000) + 10000; // 10000-99999
  return `NG-${digits}`;
}

// CreateTopup: creates a topup_requests doc using the admin SDK. Client should call this endpoint.
exports.createTopup = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send({ error: 'Method not allowed' });

    let token;
    try {
      token = await verifyToken(req);
    } catch (e) {
      return res.status(e.status || 401).send({ error: e.message || 'Unauthorized' });
    }

    const uid = token.uid;
    const centAmount = Number(req.body.centAmount || req.query.centAmount);
    if (!Number.isInteger(centAmount) || centAmount <= 0) {
      return res.status(400).send({ error: 'Invalid centAmount' });
    }

    // nairaAmount can be derived by your pricing rules; accept optional override for display
    const nairaAmount = req.body.nairaAmount ? Number(req.body.nairaAmount) : centAmount; // default 1 Naira per cent

    // Create topup doc with a unique paymentCode
    const topups = db.collection('topup_requests');

    let paymentCode = generatePaymentCode();
    // Try up to 5 times to avoid collision
    for (let i = 0; i < 5; i++) {
      const snap = await topups.where('paymentCode', '==', paymentCode).limit(1).get();
      if (snap.empty) break;
      paymentCode = generatePaymentCode();
    }

    const newDoc = {
      userId: uid,
      centAmount: centAmount,
      nairaAmount: nairaAmount,
      paymentCode: paymentCode,
      zetraAccount: null,
      receiptUrl: null,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      adminId: null,
      adminNote: null,
      approvedAt: null,
    };

    try {
      const docRef = await topups.add(newDoc);
      return res.status(201).send({ id: docRef.id, paymentCode });
    } catch (err) {
      console.error('createTopup error', err);
      return res.status(500).send({ error: 'Failed to create topup' });
    }
  });
});

// ApproveTopup: admin-only endpoint to approve or reject a topup
exports.approveTopup = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send({ error: 'Method not allowed' });

    let token;
    try {
      token = await verifyToken(req);
    } catch (e) {
      return res.status(e.status || 401).send({ error: e.message || 'Unauthorized' });
    }

    // Require admin custom claim
    if (!token.admin && !token.claims?.admin) {
      return res.status(403).send({ error: 'Admin privileges required' });
    }

    const adminId = token.uid;
    const requestId = req.body.requestId;
    const action = req.body.action; // 'approve' or 'reject'
    const adminNote = req.body.adminNote || null;

    if (!requestId || !['approve', 'reject'].includes(action)) {
      return res.status(400).send({ error: 'Missing parameters' });
    }

    const reqRef = db.collection('topup_requests').doc(requestId);

    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(reqRef);
        if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Topup request not found');
        const data = snap.data();
        if (!data) throw new functions.https.HttpsError('failed-precondition', 'Invalid data');

        // Prevent double-approval
        if (data.status === 'approved') return;
        if (data.status === 'rejected' && action === 'reject') return;

        if (action === 'reject') {
          tx.update(reqRef, {
            status: 'rejected',
            adminId: adminId,
            adminNote: adminNote,
            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }

        // Approve flow: credit the user's wallet (server-side). This uses Firestore as the authoritative ledger if you
        // do not have direct admin access to ZTC. If you do have a ZTC/Supabase admin API, prefer crediting there
        // so the ZtcWalletBridge mirrors the change.
        const userId = data.userId;
        const centAmount = Number(data.centAmount || 0);
        if (!Number.isInteger(centAmount) || centAmount <= 0) {
          throw new functions.https.HttpsError('invalid-argument', 'Invalid centAmount');
        }

        const walletRef = db.collection('wallets').doc(userId);
        const walletSnap = await tx.get(walletRef);
        const prevCents = (walletSnap.exists && walletSnap.data() && walletSnap.data().balanceCents) ? Number(walletSnap.data().balanceCents) : 0;
        const newCents = prevCents + centAmount;

        tx.set(walletRef, {
          userId: userId,
          balanceCents: newCents,
          coinBalance: Math.floor(newCents / 1000),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        const txRef = db.collection('wallet_transactions').doc();
        tx.set(txRef, {
          type: 'deposit',
          toUserId: userId,
          amountCents: centAmount,
          previousBalanceCents: prevCents,
          newBalanceCents: newCents,
          source: 'manual_admin_topup',
          requestId: requestId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        tx.update(reqRef, {
          status: 'approved',
          adminId: adminId,
          adminNote: adminNote,
          approvedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      return res.status(200).send({ success: true });
    } catch (err) {
      console.error('approveTopup error', err);
      return res.status(500).send({ error: 'Failed to process approval' });
    }
  });
});
