// Webhook server for Monnify disbursement callbacks
const express = require('express');
const crypto = require('crypto');
const admin = require('firebase-admin');

// Raw body middleware to compute HMAC over exact bytes
const rawBodyMiddleware = (req, res, next) => {
  let data = [];
  req.on('data', (chunk) => data.push(chunk));
  req.on('end', () => {
    req.rawBody = Buffer.concat(data);
    try {
      req.body = JSON.parse(req.rawBody.toString());
    } catch (e) {
      req.body = {};
    }
    next();
  });
};

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'nigergram',
});

const db = admin.firestore();

const { gistHubCronHandler } = require('./scheduled/decay_and_poll_finalizer');

const app = express();
app.use(rawBodyMiddleware);

app.post('/monnify-webhook', async (req, res) => {
  try {
    const signatureHeader = req.get('monnify-signature') || req.get('Monnify-Signature') || '';
    const secret = process.env.MONNIFY_SECRET_KEY;
    if (!secret) {
      console.error('MONNIFY_SECRET_KEY is not set');
      return res.status(500).send('Missing configuration');
    }

    const computed = crypto.createHmac('sha256', secret).update(req.rawBody).digest('hex');

    if (computed !== signatureHeader) {
      console.warn('Invalid signature', { computed, signatureHeader });
      return res.status(401).send('Invalid signature');
    }

    const payload = req.body || {};
    const responseBody = payload.responseBody || payload.data || {};
    const disbursementReference =
      responseBody.disbursementReference || responseBody.reference || responseBody.transactionReference;
    const statusRaw = responseBody.status || responseBody.disbursementStatus || payload.eventType || payload.eventName;

    if (!disbursementReference) {
      console.warn('Webhook missing disbursementReference', { payload });
      await db.collection('monnify_webhook_audit').add({
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        payload,
      });
      return res.status(400).send('Missing disbursement reference');
    }

    const statusUpper = (statusRaw || '').toString().toUpperCase();
    const successStatuses = ['SUCCESS', 'COMPLETED', 'PAID'];
    const failedStatuses = ['FAILED', 'DECLINED', 'REJECTED', 'CANCELLED'];

    const q = await db.collection('withdrawal_requests')
      .where('monnifyDisbursementReference', '==', disbursementReference)
      .limit(1)
      .get();

    if (q.empty) {
      console.warn('Withdrawal request not found for disbursementReference', disbursementReference);
      await db.collection('monnify_webhook_audit').add({
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        payload,
      });
      return res.status(200).send('No matching withdrawal request');
    }

    const reqDoc = q.docs[0];
    const reqRef = reqDoc.ref;
    const reqData = reqDoc.data();

    const currentStatus = reqData.status;
    if (currentStatus === 'paid' || currentStatus === 'failed') {
      return res.status(200).send('Already final');
    }

    if (successStatuses.includes(statusUpper)) {
      await reqRef.update({
        status: 'paid',
        monnifyWebhookPayload: payload,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const txQ = await db.collection('wallet_transactions')
        .where('withdrawalRequestId', '==', reqRef.id)
        .where('type', '==', 'withdrawal')
        .limit(1)
        .get();

      if (!txQ.empty) {
        await txQ.docs[0].ref.update({
          status: 'completed',
        });
      }

      return res.status(200).send('OK: marked paid');
    }

    if (failedStatuses.includes(statusUpper)) {
      const coinAmount = (reqData.coinAmount || 0);
      const creatorId = reqData.creatorId;

      await db.runTransaction(async (tx) => {
        const walletRef = db.collection('wallets').doc(creatorId);
        const walletSnap = await tx.get(walletRef);
        const walletData = walletSnap.exists ? walletSnap.data() : {};
        const currentBalance = (walletData && walletData.coinBalance) ? walletData.coinBalance : 0;
        const newBalance = currentBalance + coinAmount;

        tx.update(walletRef, {
          coinBalance: newBalance,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        tx.update(reqRef, {
          status: 'failed',
          failureReason: `Monnify webhook status: ${statusUpper}`,
          monnifyWebhookPayload: payload,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const txQ = await db.collection('wallet_transactions')
          .where('withdrawalRequestId', '==', reqRef.id)
          .where('type', '==', 'withdrawal')
          .limit(1)
          .get();

        if (!txQ.empty) {
          tx.update(txQ.docs[0].ref, { status: 'failed' });
        }

        const refundTxRef = db.collection('wallet_transactions').doc();
        tx.set(refundTxRef, {
          fromUserId: 'system',
          toUserId: creatorId,
          fromUsername: 'system',
          toUsername: '',
          coinAmount: coinAmount,
          type: 'withdrawal_refund',
          status: 'completed',
          relatedWithdrawalRequestId: reqRef.id,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      return res.status(200).send('OK: failed and refunded');
    }

    // Unknown/processing status -> mark as processing and save payload
    await reqRef.update({
      status: 'processing',
      monnifyWebhookPayload: payload,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).send('OK: processing');
  } catch (err) {
    console.error(err);
    return res.status(500).send('server error');
  }
});

app.get('/payment-callback', (req, res) => {
  const amount = req.query.amount;
  const reference = req.query.paymentReference || req.query.transactionReference || '';

  const amountBlock = amount
    ? `<p class="amount">₦${Number(amount).toLocaleString()}</p><p class="sub">added to your wallet</p>`
    : `<p class="sub">Your coins will appear in your wallet shortly.</p>`;

  res.status(200).send(`
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <title>Payment Complete — NigerGram</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: radial-gradient(circle at top, #1a1a1a 0%, #0a0a0a 70%);
            color: #ffffff;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            padding: 24px;
          }
          .card {
            width: 100%;
            max-width: 380px;
            text-align: center;
            animation: fadeUp 0.5s ease-out;
          }
          @keyframes fadeUp {
            from { opacity: 0; transform: translateY(16px); }
            to { opacity: 1; transform: translateY(0); }
          }
          .check-circle {
            width: 84px;
            height: 84px;
            margin: 0 auto 24px;
            border-radius: 50%;
            background: linear-gradient(135deg, #FFD700, #FF6B00);
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 0 40px rgba(255, 165, 0, 0.35);
            animation: pop 0.4s ease-out 0.15s both;
          }
          @keyframes pop {
            0% { transform: scale(0.6); opacity: 0; }
            100% { transform: scale(1); opacity: 1; }
          }
          .check-circle svg { width: 40px; height: 40px; }
          h1 {
            font-size: 22px;
            font-weight: 700;
            margin-bottom: 8px;
            letter-spacing: -0.2px;
          }
          .amount {
            font-size: 32px;
            font-weight: 800;
            margin: 16px 0 4px;
            background: linear-gradient(135deg, #FFD700, #FF6B00);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
          }
          .sub {
            font-size: 14px;
            color: #999999;
            margin-bottom: 28px;
          }
          .ref {
            font-size: 11px;
            color: #555555;
            margin-bottom: 32px;
            word-break: break-all;
          }
          .instruction {
            font-size: 14px;
            color: #cccccc;
            line-height: 1.6;
            padding: 16px 20px;
            background: rgba(255, 255, 255, 0.04);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 14px;
          }
          .brand {
            margin-top: 40px;
            font-size: 12px;
            color: #444444;
            letter-spacing: 1px;
            text-transform: uppercase;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="check-circle">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M20 6L9 17L4 12" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <h1>Payment Successful</h1>
          ${amountBlock}
          ${reference ? `<p class="ref">Ref: ${reference}</p>` : ''}
          <div class="instruction">
            You can close this window now and return to the NigerGram app to see your updated coin balance.
          </div>
          <div class="brand">🇳🇬 NigerGram</div>
        </div>
      </body>
    </html>
  `);
});

app.get('/cron/gist-hub', gistHubCronHandler);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Monnify webhook server listening on port ${PORT}`);
});
