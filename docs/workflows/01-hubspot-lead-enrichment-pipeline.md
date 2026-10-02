# Workflow 1: HubSpot Lead Enrichment Pipeline

[← Back to README](../../README.md)

**Status:** v1.0.0 published

## Problem

Inbound leads arrive with only a name, an email, and a company domain. The information needed to qualify them (company size, industry signals, technology stack, domain age) is not in the payload. Someone has to manually look up the company, decide whether the lead is worth pursuing, and enter the contact into the CRM.

This workflow automates the intake. It enriches the company domain, scores the lead against countable criteria, creates a HubSpot contact, creates a deal associated with that contact for high-scoring leads, and logs every run to Supabase for audit.

The design pattern is intentionally the same as the v1 portfolio's AI Lead Qualification Agent. The difference is the output layer: this workflow writes to a commercial CRM (HubSpot) instead of a Supabase table, using the same deterministic scoring approach.

## Architecture

```
Webhook (POST /hubspot-lead-intake)
→ Validate Lead Payload (Code: validate fields, normalize domain, attach run_id)
→ Enrich Company (HTTP: Apify company-data-enricher, sync mode)
→ Extract Enrichment Signals (Code: flatten Apify response into scored fields)
→ Build Groq Body (Code: assemble the full Groq request body)
→ Score with Groq (HTTP: openai/gpt-oss-20b, temperature 0, response_format json_object)
→ Parse Score (Code: parse content, validate score, build criteria_met_sql)
→ Filter High (Code: keep items where score === 'high')
→ Create HubSpot Contact (HTTP: POST /crm/v3/objects/contacts/batch/upsert)
→ Create HubSpot Deal (HTTP: POST /crm/v3/objects/deals with inline association)
→ Log Run to Supabase (Postgres: INSERT into lead_enrichment_runs)
```

Eleven nodes. One inbound webhook. One outbound CRM write.

## Key implementation details

- **Deterministic lead scoring.** The same five countable criteria and the same three-part structure as v1's Lead Qualification Agent: temperature 0, explicit criteria with numeric thresholds, and an ambiguity clause that biases toward the lower score. `high` requires 2 or more criteria. `medium` requires exactly 1. `low` requires 0.

- **Company enrichment via Apify.** The `miccho27~company-data-enricher` actor runs in sync mode (`/run-sync-get-dataset-items`) and returns page title, description, OG tags, RDAP registration data, social links, technology stack, and contact information. Sync mode is used because the workflow needs the enrichment result before it can score.

- **Normalized enrichment shape.** The `Extract Enrichment Signals` Code node flattens the raw Apify response into a fixed set of fields. Downstream nodes and the Supabase audit table reference this flattened shape, not the raw Apify output. This means the Apify response shape can change without breaking the workflow.

- **Domain normalization happens once.** The `Validate Lead Payload` node strips `https://`, `www.`, and any path from `company_domain`, then lowercases it. Every downstream node reads the normalized form.

- **Idempotent contact write.** `POST /crm/v3/objects/contacts/batch/upsert` with `idProperty: "email"` means the workflow creates the contact on first run and updates it on subsequent runs. No duplicate contact records. The response shape is a batch wrapper with `results[0].id`.

- **Inline deal-contact association.** The deal creation body includes an `associations` array with `associationCategory: "HUBSPOT_DEFINED"` and `associationTypeId: 3`. One API call creates both the deal and the association. No separate association call needed.

- **Idempotent Supabase write.** `run_id` carries a unique index. The INSERT uses `ON CONFLICT (run_id) DO NOTHING`. Re-running the same execution does not duplicate the audit row.

- **Precomputed SQL for arrays.** The `criteria_met` column is `TEXT[]` in Postgres. The `Parse Score` node builds a Postgres-compatible array literal (`ARRAY['a','b']::text[]`) as a separate `criteria_met_sql` field. This avoids n8n's broken inline `ARRAY[...]` expression pattern.

## Verified behavior

Full execution from webhook to Supabase log, one inbound lead, one clean run:

| Node | Output |
|------|--------|
| `Receive Lead` | 1 item, POST body with name, email, company_domain, message |
| `Validate Lead Payload` | `valid: true`, `run_id` assigned, `company_domain` normalized to `acme.ph` |
| `Enrich Company` | Apify response with populated `metadata.title` and `metadata.description` |
| `Extract Enrichment Signals` | Flattened enrichment object, `enrichment_available: true` |
| `Build Groq Body` | Request body with 5-criteria system prompt and lead context |
| `Score with Groq` | `finish_reason: "stop"`, score `high`, 545 prompt tokens, 208 completion tokens |
| `Parse Score` | `score: "high"`, `criteria_met: ["Company Maturity", "Specific Solution Request"]`, `criteria_met_sql` built |
| `Filter High` | 1 item kept |
| `Create HubSpot Contact` | Contact ID `562709905125`, upsert `new: false` on second run |
| `Create HubSpot Deal` | Deal ID created, `dealstage: qualifiedtobuy`, associated with contact |
| `Log Run to Supabase` | Row inserted with contact ID, deal ID, score, criteria, and reasoning |

Screenshots:

- `docs/images/01-canvas.png` — full workflow canvas, all nodes green
- `docs/images/01-groq-score.png` — Groq response showing criteria_met and reasoning
- `docs/images/01-hubspot-deal.png` — HubSpot deal detail with association to the contact
- `docs/images/01-supabase-audit.png` — `lead_enrichment_runs` row with full audit trail

## Stack

n8n 2.8.4 (self-hosted) · HubSpot CRM API v3 · Apify (`miccho27/company-data-enricher`) · Groq (`openai/gpt-oss-20b`, temperature 0) · Supabase (PostgreSQL) · Cloudflare Tunnel

## Gotchas

**Groq free-tier TPM is a rolling 60-second window.** Single-call classification per lead keeps usage well under the 8,000 TPM ceiling. This workflow does not batch because it processes one lead per webhook.

**`reasoning_effort: "low"` on `gpt-oss-20b`.** Without it, reasoning tokens consume the completion budget and the JSON response truncates. Symptom: `finish_reason: "length"` or missing fields in the parsed output.

**HTTP Request node: leading `=` is sent as literal text on n8n 2.8.4.** In both `Using JSON` and `Raw` body modes, pasting `={{ expression }}` sends a body that starts with `=`. HubSpot and Groq reject the request. Fix: paste `{{ expression }}` without the `=` prefix.

**The Filter and Switch nodes in n8n 2.8.4 discard items whose comparison should succeed.** Confirmed byte-clean string (`len: 4`, `codes: [104, 105, 103, 104]`) still discarded when compared to the literal `high`. Replaced with a Code node using strict JavaScript equality. See `workflows/hubspot-lead-enrichment-pipeline.json` for the inline comment.

**HubSpot v3 contact creation returns 409 on duplicate email.** The single-object endpoint does not deduplicate. Switch to `/crm/v3/objects/contacts/batch/upsert` with `idProperty: "email"`. Response shape changes: contact ID lives at `results[0].id`, not at the top level.

**HubSpot's `hs_num_associated_contacts` field is computed asynchronously.** Immediately after deal creation with an inline association, this field may show `"0"`. Refresh the deal in the HubSpot UI after 15-30 seconds. Do not treat the immediate API response as authoritative for association counts.

**Apify sync mode has a cold-start delay.** First run of the actor per session takes 10-20 seconds. The HTTP Request node sets a 60-second timeout to cover this. Subsequent runs in the same session return in 5-15 seconds.

**Empty Apify response for fictional domains.** For non-existent domains like `acme.ph`, `domainInfo`, `socialLinks`, and `contact` fields are null. The `Extract Enrichment Signals` node detects this and sets `enrichment_available: false`. The scorer then relies on the message content alone.

## Estimated impact

Manual lead intake for a small team takes 5-15 minutes per lead: look up the company, decide whether it is worth pursuing, create the contact, decide whether to create a deal, enter notes. This workflow does the same work in 15-25 seconds of wall-clock time, and it does it consistently. Every lead that arrives at the webhook gets the same scoring treatment, the same enrichment, and the same CRM write pattern.

The audit trail in Supabase makes the pipeline reversible. Every score, every criterion, every reasoning string is preserved. If a lead scores high and someone later questions whether it should have, the answer is in the row.

## Monitored by

Not yet monitored. Cross-workflow monitoring is a planned addition in the sibling repo's [Workflow Health Monitor](https://github.com/Xhenzouu/n8n-automation-portfolio/blob/main/docs/workflows/10-workflow-health-monitor.md).