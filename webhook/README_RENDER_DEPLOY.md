Monnify Webhook server (Render.com deployment

This server listens for Monnify disbursement webhooks and updates Firestore.

Files:
- index.js
- package.json

Environment variables (set these in Render dashboard):
- SERVICE_ACCOUNT_JSON: (Firebase service account JSON as a single string)
- MONNIFY_SECRET_KEY: (Monnify secret key for HMAC verification)
- PORT: (Render provides this automatically)

Deploy steps:
1. Push the `webhook/` folder to your GitHub repo (or ensure it is in the repo).
2. On Render.com, create a new Web Service:
   - Connect to the repo and specify the `webhook/` directory as the root (subpath).
   - Build command: `npm install`
   - Start command: `npm start`
   - Instance: Free tier is fine.
3. Add environment variables in Render:
   - SERVICE_ACCOUNT_JSON: paste the entire Firebase service account JSON (ensure this is protected)
   - MONNIFY_SECRET_KEY: your Monnify secret key (sandbox for testing)
4. Deploy. Render will assign a public URL.
5. In Monnify dashboard, configure webhook URL:
   - Example: `https://<your-render-host>/monnify-webhook`
6. Test the endpoint (see notes below).

Notes:
- Ensure SERVICE_ACCOUNT_JSON is the full JSON object (single-line or newline-preserved string) that corresponds to a Firebase service account with Firestore access.
- The server uses HMAC-SHA256 verification of the 'monnify-signature' header. Use the same MONNIFY_SECRET_KEY set in Monnify dashboard.
