# Top-up configuration (Firestore)

This file documents the Firestore document used to store temporary/manual payment details for NigerGram top-ups. The application reads `config/topup` to display account details on the Buy Cent screen.

Create a document at: `config/topup`

Recommended fields:
- accountNumber: string (e.g. "8065425732")
- accountName: string (e.g. "Oyedele Toluwani")
- provider: string (e.g. "OPay")
- nairaPerCent: integer (optional, default: 1) - conversion rate used to show Naira amount to pay for a given cent amount.

Example (Firestore document JSON):
{
  "accountNumber": "8065425732",
  "accountName": "Oyedele Toluwani",
  "provider": "OPay",
  "nairaPerCent": 1
}

Notes:
- These are temporary payment details and should be updated when you switch to a dedicated Zetra/NigerGram business account.
- Only admins should have write access to this document. Use Firestore security rules to restrict updates to users with the `admin` custom claim.
