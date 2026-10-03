# Platform Integration Portfolio

Production integrations with commercial SaaS platforms, built with self-hosted n8n and free developer accounts.

## Thesis

Most automation portfolios demonstrate free-tier tools. Production integrations require connecting commercial platforms that charge $100 to $500 per month. This portfolio demonstrates the same integration patterns using free developer accounts wherever possible, and documents the platform-specific gotchas that only appear when wiring real APIs: OAuth scopes, rate limits, sandbox quirks, and webhook verification.

The goal is not to show that n8n can call an API. The goal is to show the wiring, the failure modes, and the recovery patterns that only surface in real integrations.

## Sibling Portfolio

This repo is the platform integration layer. The AI automation layer lives in a separate repo:

- [n8n-automation-portfolio](https://github.com/Xhenzouu/n8n-automation-portfolio) covers LLM workflows, RAG pipelines, AI agents with tool calling, and MCP integration.

The two repos are designed to be read together. This one shows how to connect to the platforms that businesses actually run. The other shows how to reason over the data that flows through them.

## Quick Tour

| # | Workflow | Platforms | Pattern |
|---|----------|-----------|---------|
| 1 | [HubSpot Lead Enrichment Pipeline](docs/workflows/01-hubspot-lead-enrichment-pipeline.md) | HubSpot, Apify, Groq, Supabase | Inbound lead, enrich, score, create contact and conditional deal |
| 2 | [Shopify Order Confirmation Pipeline](docs/workflows/02-shopify-order-confirmation-pipeline.md) | Shopify, Resend, Supabase | Order webhook, HMAC verify, HTML email, order note, audit log |

More workflows will be added incrementally. Each will follow the same documentation structure: architecture diagram, key implementation details, verified behavior with screenshots, and platform-specific gotchas.

## Stack

n8n (self-hosted) · HubSpot API · Shopify Admin API · Resend API · WhatsApp Cloud API · Supabase (PostgreSQL) · Groq · Apify · Cloudflare Tunnel

## Repo Structure

```
workflows/      # n8n workflow JSON exports. Sanitized before commit.
docs/
  workflows/    # One markdown file per workflow.
  images/       # Screenshots referenced by the workflow docs.
scripts/        # Utility scripts (sanitize-workflows.ps1)
README.md
LICENSE
.gitignore
```

## Gotchas

**Groq free-tier TPM is a rolling 60-second window.** Single-call classification per lead keeps usage well under the 8,000 TPM ceiling. This workflow does not batch because it processes one lead per webhook.

**`reasoning_effort: "low"` on `gpt-oss-20b`.** Without it, reasoning tokens consume the completion budget and the JSON response truncates. Symptom: `finish_reason: "length"` or missing fields in the parsed output.

**HTTP Request node: leading `=` is sent as literal text on n8n 2.8.4.** In both `Using JSON` and `Raw` body modes, pasting `={{ expression }}` sends a body that starts with `=`, not `{`. HubSpot, Groq, and any JSON-strict API reject the request. Fix: paste `{{ expression }}` without the `=` prefix. The field's expression toggle handles expression mode.

**The Filter and Switch nodes in n8n 2.8.4 discard items whose comparison should succeed.** Confirmed byte-clean string (`len: 4`, `codes: [104, 105, 103, 104]`) still discarded when compared to the literal `high`. Replaced with a Code node using strict JavaScript equality. See `workflows/hubspot-lead-enrichment-pipeline.json` for the inline comment.

**HubSpot v3 contact creation returns 409 on duplicate email.** The single-object endpoint does not deduplicate. Switch to `/crm/v3/objects/contacts/batch/upsert` with `idProperty: "email"`. Response shape changes: contact ID lives at `results[0].id`, not at the top level.

**HubSpot's `hs_num_associated_contacts` field is computed asynchronously.** Immediately after deal creation with an inline association, this field may show `"0"`. Refresh the deal in the HubSpot UI after 15-30 seconds. Do not treat the immediate API response as authoritative for association counts.

**Apify sync mode has a cold-start delay.** First run of the actor per session takes 10-20 seconds. The HTTP Request node sets a 60-second timeout to cover this. Subsequent runs in the same session return in 5-15 seconds.

**Empty Apify response for fictional domains.** For non-existent domains like `acme.ph`, `domainInfo`, `socialLinks`, and `contact` fields are null. The `Extract Enrichment Signals` node detects this and sets `enrichment_available: false`. The scorer then relies on the message content alone.

**n8n 2.8.4 blocks `require('crypto')` in Code nodes by default.** The env var `NODE_FUNCTION_ALLOW_BUILTIN=crypto` must be set in the shell that starts n8n. Needed for HMAC-based webhook verification (e.g. Shopify).

**Resend free tier restricts recipients to the account owner's email address.** Any recipient other than the address registered on the Resend account is rejected with `403`. Verify a domain for production sending.

## Sanitize Before Commit

Workflow JSON exports from n8n contain instance-specific values that must not be committed. Before every commit that touches `workflows/`, run the sanitize script at `scripts/sanitize-workflows.ps1`, which strips:

- Supabase project refs
- Telegram chat IDs
- Cloudflare tunnel URLs
- Any API key that appears in a node parameter as a plain value

The full list of patterns and the PowerShell replacement command are documented in the [v1 portfolio's sanitize convention](https://github.com/Xhenzouu/n8n-automation-portfolio#setup). This repo references that list rather than duplicating it, so the two stay in sync.

The `.gitignore` in this repo blocks the most common accidental leaks (`.env` variants, local SQLite files, scratch files containing tunnel URLs). It does not replace the manual sanitize pass.

## Setup

Setup instructions will be added as each workflow lands. They will cover:

1. Platform account creation (free developer tier)
2. API credentials and OAuth setup
3. n8n credential configuration
4. Importing the workflow JSON
5. Testing with sample payloads

## Status

Workflow 1 shipped. HubSpot Lead Enrichment Pipeline runs end-to-end from webhook to CRM write to audit log.

Workflow 2 shipped. Shopify Order Confirmation Pipeline runs end-to-end from Shopify webhook to Resend email to Shopify order note to Supabase audit log, with a companion error handler workflow that writes failure rows to the same audit table.

More workflows will be added incrementally.

## About

Built by [Henson Brix A. Arroyo](https://hensonbrix-portfolio.vercel.app).

- GitHub: [@Xhenzouu](https://github.com/Xhenzouu)
- Portfolio: [hensonbrix-portfolio.vercel.app](https://hensonbrix-portfolio.vercel.app)
- Email: arroyobrix@gmail.com

## License

MIT