#!/usr/bin/env bash
# Loads the schema, views and demo data into a Postgres database and checks
# that each health-check view flags exactly the demo case it was built for.
# Usage: DATABASE_URL=postgres://... ./tests/run_sql_tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PSQL=(psql "${DATABASE_URL:?set DATABASE_URL}" -v ON_ERROR_STOP=1 -qAt)

for f in sql/01_schema.sql sql/02_billing_checks.sql sql/03_seed_demo.sql; do
  "${PSQL[@]}" -f "$f" >/dev/null
done

check() {  # check <description> <sql> <expected>
  local got
  got=$("${PSQL[@]}" -c "$2")
  if [[ "$got" == "$3" ]]; then echo "PASS  $1"; else echo "FAIL  $1: expected '$3', got '$got'"; exit 1; fi
}

check "overdue invoices"            "select organization from billing.overdue_invoices"          "Nimbus Labs"
check "overpaid (duplicate charge)" "select organization || ':' || overpaid_cents from billing.overpaid_invoices" "Kite Studio:2950"
check "paid but still open"         "select organization from billing.paid_but_open_invoices"    "Quartz Data"
check "repeat payment failures"     "select organization || ':' || failed_last_30_days from billing.repeat_payment_failures" "Pebble Apps:3"
check "EU org missing VAT ID"       "select organization from billing.eu_orgs_missing_vat_id"    "Acme Analytics"
check "tax on exempt org"           "select organization from billing.tax_on_exempt_orgs"        "Orbit Nonprofit"
check "top failure reason"          "select failure_reason from billing.failure_reasons limit 1" "card_declined"
echo "All SQL checks passed."
