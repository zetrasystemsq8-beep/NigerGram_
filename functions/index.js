const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });
const { createClient } = require('@supabase/supabase-js');

admin.initializeApp();
const db = admin.firestore();

// Initialize Supabase admin client if env vars present
const SUPABASE_URL = process.env.SUPABASE_URL || functions.config().supabase?.url;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || functions.config().supabase?.service_key;
let supabase = null;
if (SUPABASE_URL && SUPABASE_SERVICE_KEY) {
  supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, { auth: { persistSession: false } });
  console.log('Supabase client initialized');
} else {
  console.log('Supabase not configured; approveTopup requires Supabase to be set up');
}

// Helper: verify Firebase ID token from Authorization header
async function verifyToken(req) {
  const auth = req.get('Authorization') || req.get('authorization');
  if (!auth || !auth.startsWith('Bearer ')) throw { status: 401, message: 'Missing Authorization' };
  const idToken = auth.split('Bearer ')[1];
  // First try Firebase token verification
  try {
    return await admin.auth().verifyIdToken(idToken);
  } catch (e) {
    // If Firebase verification fails, try Supabase token (access token) if configured
    if (!supabase) {
      throw { status: 401, message: 'Invalid token' };
    }
    try {
      // supabase.auth.getUser expects an access token
      const result = await supabase.auth.getUser(idToken);
      if (result.error) {
        throw result.error;
      }
      const user = result.data?.user;
      if (!user) throw new Error('Supabase user not found');

      // Map Supabase user to a token-like object expected by callers
      const mapped = {
        uid: user.id,
        // Attempt to detect an admin flag in common metadata locations
        admin: (user.user_metadata && (user.user_metadata.admin === true || user.user_metadata.isAdmin === true)) 
                || (user.app_metadata && (user.app_metadata.admin === true || user.app_metadata.role === 'admin'))
      };
      return mapped;
    } catch (supErr) {
      console.error('Token verification failed:', supErr);
      throw { status: 401, message: 'Invalid token' };
    }
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

// Helper: credit Supabase app_currency_balances by calling the idempotent RPC/stored-proc created in Postgres.
async function creditSupabaseBalance(userId, centAmount, requestId, adminId) {
  if (!supabase) throw new Error('Supabase not configured');

  // Call the Postgres stored procedure we asked you to create: credit_app_balance
  // It is expected to be idempotent (unique audit on request_id) and to perform the upsert in a single transaction.
  const params = {
    p_user_id: userId,
    p_app_id: 'nigergram',
    p_cent_amount: Number(centAmount),
    p_request_id: requestId,
    p_admin_id: adminId || null,
  };

  const { data, error } = await supabase.rpc('credit_app_balance', params);
  if (error) {
    throw error;
  }
  // data typically contains rows returned by the function. We'll return it for auditing.
  return data;
}

// ApproveTopup: admin-only endpoint to approve or reject a topup
// IMPORTANT: This function now requires Supabase to be configured and the credit_app_balance RPC to exist.
// There is NO Firestore fallback for normal operation by your instruction.
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
      // First step: lock and validate the request by setting status -> 'processing' atomically.
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(reqRef);
        if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Topup request not found');
        const data = snap.data();
        if (!data) throw new functions.https.HttpsError('failed-precondition', 'Invalid data');

        // Prevent double-approval
        if (data.status === 'approved') throw new functions.https.HttpsError('already-exists', 'Already approved');
        if (data.status === 'processing') throw new functions.https.HttpsError('already-exists', 'Already being processed');

        // Allow owner or admin to reject/approve; here we just set processing for approve flow
        if (action === 'approve') {
          tx.update(reqRef, {
            status: 'processing',
            adminId: adminId,
            adminNote: adminNote,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } else if (action === 'reject') {
          tx.update(reqRef, {
            status: 'rejected',
            adminId: adminId,
            adminNote: adminNote,
            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });

      if (action === 'reject') {
        return res.status(200).send({ success: true, status: 'rejected' });
      }

      // Load the request data (fresh)
      const snap = await reqRef.get();
      const data = snap.data();
      if (!data) throw new Error('Request missing after lock');

      const userId = data.userId;
      const centAmount = Number(data.centAmount || 0);
      if (!Number.isInteger(centAmount) || centAmount <= 0) {
        // revert processing -> pending
        await reqRef.update({ status: 'pending', updatedAt: admin.firestore.FieldValue.serverTimestamp(), adminNote: 'Invalid centAmount' });
        throw new Error('Invalid centAmount');
      }

      if (!supabase) {
        // Explicit failure: Supabase must be configured for approveTopup to work in canonical mode.
        await reqRef.update({ status: 'pending', updatedAt: admin.firestore.FieldValue.serverTimestamp(), adminNote: 'Supabase not configured' });
        return res.status(500).send({ error: 'Supabase not configured. ApproveTopup requires Supabase and the credit_app_balance RPC.' });
      }

      // Call the RPC to credit the canonical ZTC ledger. This RPC must be idempotent (we provided SQL for that).
      try {
        const rpcResult = await creditSupabaseBalance(userId, centAmount, requestId, adminId);

        // Mark request approved; ZtcWalletBridge will mirror the change into Firestore (wallets/*) and create a deposit tx.
        await reqRef.update({ status: 'approved', approvedAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp(), adminNote: adminNote });

        return res.status(200).send({ success: true, status: 'approved', method: 'supabase', rpcResult });
      } catch (supErr) {
        console.error('Supabase RPC credit failed', supErr);
        // revert processing -> pending and record note
        await reqRef.update({ status: 'pending', updatedAt: admin.firestore.FieldValue.serverTimestamp(), adminNote: `Supabase RPC error: ${supErr.message || supErr}` });
        return res.status(500).send({ error: 'Failed to credit Supabase via RPC', details: String(supErr) });
      }
    } catch (err) {
      console.error('approveTopup error', err);
      if (err instanceof functions.https.HttpsError) {
        return res.status(400).send({ error: err.message });
      }
      return res.status(500).send({ error: 'Failed to process approval', details: String(err) });
    }
  });
});
