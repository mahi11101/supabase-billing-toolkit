# Supabase Billing Toolkit

SQL health checks and a cost estimator for the billing questions support teams answer every day:

- *"Why is my bill $45 when Pro is $25?"*
- *"My card was charged, but the invoice still says unpaid."*
- *"I was charged twice."*
- *"We're a non-profit. Why is there tax on our invoice?"*

It has two parts:

1. **Billing health-check views for Postgres / Supabase** (`sql/`). A small billing schema and nine views that flag overdue invoices, duplicate charges, payment/invoice sync issues, repeat payment failures, EU customers missing a VAT ID, and tax charged to exempt customers.
2. **A monthly cost estimator for Supabase organizations** (`estimator/`). It applies Supabase's compute billing rules: hourly billing, partial hours rounded up, Nano billed as Micro on paid plans, and $10 compute credits that cover compute only.

Everything is tested: the SQL against Postgres 16 and the estimator with pytest. GitHub Actions runs both on every push.

## Quick start: cost estimator

```bash
python estimator/estimate.py micro micro micro
```

```
Plan fee                    $    25.00
Project 1 (micro, 744 h)    $    10.00
Project 2 (micro, 744 h)    $    10.00
Project 3 (micro, 744 h)    $    10.00
Compute credits             $   -10.00
--------------------------------------
Estimated total             $    45.00
Note: compute is not covered by the Spend Cap; usage over quota is billed separately.
```

This matches the example in Supabase's billing FAQ. To model a project that changed size partway through the month, pass hours: `python estimator/estimate.py small:400 medium:344`.

Prices come from the [Supabase compute docs](https://supabase.com/docs/guides/platform/manage-your-usage/compute). Always check the [pricing page](https://supabase.com/pricing) before quoting a customer.

## Quick start: billing health checks

In a Supabase project, open the SQL Editor and run the three files in order. You can also use any Postgres database:

```bash
psql "$DATABASE_URL" -f sql/01_schema.sql
psql "$DATABASE_URL" -f sql/02_billing_checks.sql
psql "$DATABASE_URL" -f sql/03_seed_demo.sql   # optional demo data, fictional companies
```

Then query the views:

| View | Question it answers | Typical action |
| --- | --- | --- |
| `billing.invoice_balances` | What does each invoice still owe after credits and payments? | Base for every other check |
| `billing.overdue_invoices` | Which open invoices are 7+ days past due? | Dunning email or payment extension |
| `billing.overpaid_invoices` | Which invoices were paid more than once? | Refund or credit the duplicate |
| `billing.paid_but_open_invoices` | Payment succeeded, but the invoice still says open? | Escalate the sync issue to billing engineering |
| `billing.failed_payment_rate_monthly` | Is the failed-payment rate going up? | Spot processor or card-network problems |
| `billing.failure_reasons` | Why do payments fail? | Write the right macro or doc |
| `billing.repeat_payment_failures` | Who failed 3+ times in 30 days? | Proactive outreach before restriction |
| `billing.eu_orgs_missing_vat_id` | Which paying EU customers have no VAT ID? | Ask for a VAT ID so reverse charge can apply |
| `billing.tax_on_exempt_orgs` | Was tax charged to a tax-exempt customer? | Tax correction with a credit note |

```sql
select * from billing.overdue_invoices;
select * from billing.repeat_payment_failures;
```

## Run the tests

```bash
pip install pytest
python -m pytest -q tests

# needs a Postgres database you can write to
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/postgres bash tests/run_sql_tests.sh
```

## Notes

- Amounts are stored in cents (integers) so rounding never changes a total.
- The schema is a teaching model, not Supabase's internal schema. Map the views to your own billing tables.
- If you expose these tables through the Supabase API, enable Row Level Security.

## Contributing

Issues and pull requests are welcome, for example new checks (expiring cards, proration errors, credit-balance drift) or support for other plan types.

## License

MIT © 2026 Mahesh Kumar
