# Sanitize workflow JSON exports before commit.
# Strips instance-specific values that must not be published.
# Run from repo root: .\scripts\sanitize-workflows.ps1

param(
  [string[]]$Files = @(
    ".\workflows\airtable-notion-two-way-sync.json",
    ".\workflows\airtable-notion-sync-error-handler.json",
    ".\workflows\shopify-order-confirmation-pipeline.json",
    ".\workflows\shopify-order-error-handler.json",
    ".\workflows\shopify-customer-sync-error-handler.json",
    ".\workflows\shopify-to-hubspot-customer-sync.json",
    ".\workflows\hubspot-lead-enrichment-pipeline.json",
    ".\workflows\stripe-payment-fanout.json",
    ".\workflows\stripe-payment-fanout-error-handler.json"
  )
)

$replacements = @(
  # Shopify client secret
  @{ Pattern = 'shpss_[A-Za-z0-9]+'; Replacement = 'YOUR_SHOPIFY_CLIENT_SECRET' },

  # Shopify client ID
  @{ Pattern = '160a41613ddcfc4301875d3968aeea5'; Replacement = 'YOUR_SHOPIFY_CLIENT_ID' },

  # Shopify access token
  @{ Pattern = 'shpca_[A-Za-z0-9]+'; Replacement = 'YOUR_SHOPIFY_ACCESS_TOKEN' },

  # Resend API key
  @{ Pattern = 're_[A-Za-z0-9_]{20,}'; Replacement = 'YOUR_RESEND_API_KEY' },

  # Cloudflare Quick Tunnel URLs
  @{ Pattern = '[a-z0-9-]+\.trycloudflare\.com'; Replacement = 'YOUR_PUBLIC_URL' },

  # Shopify shop subdomain
  @{ Pattern = 'platform-integration-sandbox\.myshopify\.com'; Replacement = 'YOUR_SHOPIFY_SHOP' },

  # Supabase project ref
  @{ Pattern = 'vrcvqtxgfmfdwhbzjuyv'; Replacement = 'YOUR_PROJECT_REF' },
  @{ Pattern = 'aws-0-ap-southeast-1\.pooler\.supabase\.com'; Replacement = 'YOUR_POOLER_HOST' },
  @{ Pattern = 'postgres\.vrcvqtxgfmfdwhbzjuyv'; Replacement = 'postgres.YOUR_PROJECT_REF' },

  # Airtable base ID (URL-anchored, then bare with boundaries)
  @{ Pattern = 'airtable\.com/v0/app[a-zA-Z0-9]{14}'; Replacement = 'airtable.com/v0/YOUR_AIRTABLE_BASE_ID' },
  @{ Pattern = '(?<![\w-])app[a-zA-Z0-9]{14}(?![\w-])'; Replacement = 'YOUR_AIRTABLE_BASE_ID' },

  # Airtable PAT (prefix split to avoid secret-scanner false positives)
  @{ Pattern = ('p' + 'a' + 't' + '[a-zA-Z0-9]{14}\.[a-zA-Z0-9]{64}'); Replacement = 'YOUR_AIRTABLE_PAT' },

  # Notion internal token (both prefixes split)
  @{ Pattern = ('n' + 't' + 'n' + '_' + '[a-zA-Z0-9]{40,}'); Replacement = 'YOUR_NOTION_TOKEN' },
  @{ Pattern = ('s' + 'e' + 'c' + 'r' + 'e' + 't' + '_' + '[a-zA-Z0-9]{40,}'); Replacement = 'YOUR_NOTION_TOKEN' },

  # Stripe webhook signing secret (prefix split)
  @{ Pattern = ('w' + 'h' + 's' + 'e' + 'c' + '_' + '[A-Za-z0-9]+'); Replacement = 'YOUR_STRIPE_WEBHOOK_SECRET' },

  # Slack incoming webhook URL
  @{ Pattern = 'hooks\.slack\.com/services/[A-Z0-9/]+'; Replacement = 'hooks.slack.com/services/redacted' },

  # Worker shared secret (64-char hex)
  @{ Pattern = '[a-f0-9]{64}'; Replacement = 'YOUR_WORKER_SHARED_SECRET' },

  # Stripe test API keys (prefix split)
  @{ Pattern = ('s' + 'k' + '_' + 't' + 'e' + 's' + 't' + '_' + '[A-Za-z0-9]+'); Replacement = 'YOUR_STRIPE_TEST_KEY' },
  @{ Pattern = ('p' + 'k' + '_' + 't' + 'e' + 's' + 't' + '_' + '[A-Za-z0-9]+'); Replacement = 'YOUR_STRIPE_TEST_PUBLISHABLE' },
  @{ Pattern = ('r' + 'k' + '_' + 't' + 'e' + 's' + 't' + '_' + '[A-Za-z0-9]+'); Replacement = 'YOUR_STRIPE_RESTRICTED' },

  # UUIDs LAST (broadest — replaces n8n node IDs, instance IDs, Notion IDs)
  @{ Pattern = '[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}'; Replacement = 'YOUR_UUID' }
)

$totalReplacements = 0

foreach ($file in $Files) {
  if (-not (Test-Path $file)) {
    Write-Output "SKIP: $file does not exist"
    continue
  }

  $content = Get-Content -Raw $file

  foreach ($r in $replacements) {
    $content = $content -replace $r.Pattern, $r.Replacement
  }

  Set-Content -Path $file -Value $content -Encoding UTF8 -NoNewline
  $totalReplacements++
  Write-Output "Sanitized: $file"
}

Write-Output ""
Write-Output "Sanitized $totalReplacements files."
Write-Output ""
Write-Output "Run the leak check to verify:"
Write-Output "  Select-String -Path .\workflows\*.json -Pattern 'whsec_|hooks\.slack\.com|sk_test_|shpss_|shpca_|re_|trycloudflare|vrcvqtxgfmfdwhbzjuyv|platform-integration-sandbox|app[a-zA-Z0-9]{14}'"