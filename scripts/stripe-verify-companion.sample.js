// stripe-verify-companion.sample.js
// Sample version of the companion process. Copy to stripe-verify-companion.js
// and replace the environment variables with real values.
//
// Required env vars:
//   STRIPE_WEBHOOK_SECRET  - from `stripe listen` output (whsec_...)
//   N8N_WEBHOOK_URL        - full URL of the n8n production webhook
//   WORKER_SHARED_SECRET   - random string shared with n8n's Verify Worker Header node

const http = require('http');
const crypto = require('crypto');

const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;
const N8N_WEBHOOK_URL = process.env.N8N_WEBHOOK_URL;
const WORKER_SHARED_SECRET = process.env.WORKER_SHARED_SECRET;
const LISTEN_PORT = Number(process.env.LISTEN_PORT || 3000);
const REPLAY_WINDOW_SECONDS = 300;

if (!STRIPE_WEBHOOK_SECRET || !N8N_WEBHOOK_URL || !WORKER_SHARED_SECRET) {
  console.error('Missing env vars: STRIPE_WEBHOOK_SECRET, N8N_WEBHOOK_URL, WORKER_SHARED_SECRET');
  process.exit(1);
}