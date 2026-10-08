# Sanitize workflow JSON exports before commit.
# Strips instance-specific values that must not be published.
# Run from repo root: .\scripts\sanitize-workflows.ps1

param(
  [string[]]$Files = @(
    ".\workflows\shopify-order-confirmation-pipeline.json",
    ".\workflows\shopify-order-error-handler.json"
  )
)

# Add these to the list as more workflows are added to the repo
$replacements = @(
  # Shopify client secret (matches both Verify Shopify HMAC and Fetch Shopify Token)
  @{ Pattern = 'shpss_[A-Za-z0-9]+'; Replacement = 'YOUR_SHOPIFY_CLIENT_SECRET' },

  # Shopify client ID (current app)
  @{ Pattern = '160a41613ddcfc4301875d3968aeea5'; Replacement = 'YOUR_SHOPIFY_CLIENT_ID' },

  # Shopify access token (from client credentials grant)
  @{ Pattern = 'shpca_[A-Za-z0-9]+'; Replacement = 'YOUR_SHOPIFY_ACCESS_TOKEN' },

  # Resend API key
  @{ Pattern = 're_[A-Za-z0-9_]{20,}'; Replacement = 'YOUR_RESEND_API_KEY' },

  # Cloudflare Quick Tunnel URL (current and any historical)
  @{ Pattern = 'sanyo-tear-ronald-tsunami\.trycloudflare\.com'; Replacement = 'YOUR_PUBLIC_URL' },
  @{ Pattern = 'newbie-scroll-annually-relate\.trycloudflare\.com'; Replacement = 'YOUR_PUBLIC_URL' },
  @{ Pattern = 'driving-largest-rehab-citizenship\.trycloudflare\.com'; Replacement = 'YOUR_PUBLIC_URL' },
  @{ Pattern = 'inn-participants-bluetooth-draws\.trycloudflare\.com'; Replacement = 'YOUR_PUBLIC_URL' },
  @{ Pattern = 'california-transcripts-reading-wealth\.trycloudflare\.com'; Replacement = 'YOUR_PUBLIC_URL' },
  @{ Pattern = 'exhibits-criteria-foo-rotary\.trycloudflare\.com'; Replacement = 'YOUR_PUBLIC_URL' },

  # Shopify shop subdomain
  @{ Pattern = 'platform-integration-sandbox\.myshopify\.com'; Replacement = 'YOUR_SHOPIFY_SHOP' },

  # Supabase project ref (current v2 project)
  @{ Pattern = 'vrcvqtxgfmfdwhbzjuyv'; Replacement = 'YOUR_PROJECT_REF' },
  @{ Pattern = 'vrcvqtxgfmfdwhbzjuyv\.supabase\.co'; Replacement = 'YOUR_PROJECT_REF.supabase.co' },

  # Supabase pooler host (if it appears in any workflow JSON)
  @{ Pattern = 'aws-0-ap-southeast-1\.pooler\.supabase\.com'; Replacement = 'YOUR_POOLER_HOST' },

  # Postgres user for Supabase (postgres.<project-ref>)
  @{ Pattern = 'postgres\.vrcvqtxgfmfdwhbzjuyv'; Replacement = 'postgres.YOUR_PROJECT_REF' }

  # Airtable
  $content = $content -replace 'app[a-zA-Z0-9]{14}', 'appqZ4NBRcHXA6Zr4'

  # Notion data source and database IDs (32-char hex with dashes)
  $content = $content -replace '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}', '3f3ebaa1-0747-80c2-a60e-000b88f1706f'

  # Airtable PAT (starts with pat, ~14 alphanumeric, dot, 64 alphanumeric)
  $airtablePatPrefix = 'p' + 'a' + 't'
  $content = $content -replace ($airtablePatPrefix + '[a-zA-Z0-9]{14}\.[a-zA-Z0-9]{64}'), 'YOUR_AIRTABLE_PAT'

  # Notion internal token
  $notionPrefix = 'n' + 't' + 'n' + '_'
  $content = $content -replace ($notionPrefix + '[a-zA-Z0-9]{40,}'), 'YOUR_NOTION_TOKEN'
  $notionSecretPrefix = 's' + 'e' + 'c' + 'r' + 'e' + 't' + '_'
  $content = $content -replace ($notionSecretPrefix + '[a-zA-Z0-9]{40,}'), 'YOUR_NOTION_TOKEN'
)

$totalReplacements = 0

foreach ($file in $Files) {
  if (-not (Test-Path $file)) {
    Write-Output "SKIP: $file does not exist"
    continue
  }

  $content = Get-Content -Raw $file
  $originalLength = $content.Length

  foreach ($r in $replacements) {
    $content = $content -replace $r.Pattern, $r.Replacement
  }

  Set-Content -Path $file -Value $content -Encoding UTF8 -NoNewline
  $totalReplacements++
  Write-Output "Sanitized: $file"
}

Write-Output ""
Write-Output "Sanitized $totalReplacements files."
Write-Output "Run the leak check to verify:"
Write-Output "  Select-String -Path .\workflows\*.json -Pattern 'shpss_|shpca_|re_|trycloudflare|vrcvqtxgfmfdwhbzjuyv|platform-integration-sandbox'"