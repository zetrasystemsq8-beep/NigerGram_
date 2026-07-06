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

app.get('/cron/gist-hub', gistHubCronHandler);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Monnify webhook server listening on port ${PORT}`);
});
