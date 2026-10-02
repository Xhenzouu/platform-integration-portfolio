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
| 1 | HubSpot Lead Enrichment Pipeline | HubSpot, Apify, Groq, Supabase | Inbound lead, enrich, score, create contact and conditional deal |

More workflows will be added incrementally. Each will follow the same documentation structure: architecture diagram, key implementation details, verified behavior with screenshots, and platform-specific gotchas.

## Stack

n8n (self-hosted) · HubSpot API · Shopify Admin API · WhatsApp Cloud API · Supabase (PostgreSQL) · Groq · Apify · Cloudflare Tunnel

## Repo Structure

```
workflows/      # n8n workflow JSON exports. Sanitized before commit.
docs/
  workflows/    # One markdown file per workflow.
  images/       # Screenshots referenced by the workflow docs.
README.md
LICENSE
.gitignore
```

## Gotchas

**HTTP Request node: leading `=` is sent as literal text in both body modes on n8n 2.8.4.** In `Using JSON` and `Raw` body modes, pasting `={{ expression }}` sends a body that starts with `=`, not `{`. HubSpot, Groq, and any JSON-strict API reject the request. Fix: paste `{{ expression }}` without the `=` prefix. The field's expression toggle handles expression mode.

**HubSpot v3 deal creation returns `hs_num_associated_contacts: "0"` even when the association succeeded.** The count is computed asynchronously. Confirm associations via the HubSpot UI, not the immediate API response. Inline `associations` in the deal creation body works and does not require a separate association call.

**HubSpot v3 contact creation returns 409 on duplicate email.** Switch to `/crm/v3/objects/contacts/batch/upsert` with `idProperty: "email"`. The response shape changes: the ID lives at `results[0].id`, not at the top level. Downstream nodes must reach back with the new path.

## Sanitize Before Commit

Workflow JSON exports from n8n contain instance-specific values that must not be committed. Before every commit that touches `workflows/`, run a find-and-replace pass to strip:

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

Early. First workflow in progress. Structure and conventions are in place.

## About

Built by [Henson Brix A. Arroyo](https://hensonbrix-portfolio.vercel.app).

- GitHub: [@Xhenzouu](https://github.com/Xhenzouu)
- Portfolio: [hensonbrix-portfolio.vercel.app](https://hensonbrix-portfolio.vercel.app)
- Email: arroyobrix@gmail.com

## License

MIT