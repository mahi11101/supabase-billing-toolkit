-- Supabase Billing Toolkit: billing health-check views
-- Each view answers a question a billing support specialist asks every day.
-- Run after 01_schema.sql. Safe to re-run.

-- 1. Balance of every invoice: total due, minus credit notes, minus successful payments.
create or replace view billing.invoice_balances as
select
  i.id                                             as invoice_id,
  i.org_id,
  i.status,
  i.amount_cents + i.tax_cents                     as total_cents,
  coalesce(c.credited_cents, 0)                    as credited_cents,
  coalesce(p.paid_cents, 0)                        as paid_cents,
  i.amount_cents + i.tax_cents
    - coalesce(c.credited_cents, 0)
    - coalesce(p.paid_cents, 0)                    as balance_cents
from billing.invoices i
left join (
  select invoice_id, sum(amount_cents) as credited_cents
  from billing.credit_notes group by invoice_id
) c on c.invoice_id = i.id
left join (
  select invoice_id, sum(amount_cents) as paid_cents
  from billing.payments where status = 'succeeded' group by invoice_id
) p on p.invoice_id = i.id;

-- 2. Open invoices more than 7 days past due (candidates for dunning or a payment extension).
create or replace view billing.overdue_invoices as
select
  i.id as invoice_id,
  o.name as organization,
  o.billing_email,
  b.balance_cents,
  i.due_date,
  (current_date - i.due_date) as days_overdue
from billing.invoices i
join billing.organizations o on o.id = i.org_id
join billing.invoice_balances b on b.invoice_id = i.id
where i.status = 'open'
  and i.due_date < current_date - 7
  and b.balance_cents > 0
order by days_overdue desc;

-- 3. Overpaid invoices (likely duplicate charges that need a refund or credit).
create or replace view billing.overpaid_invoices as
select
  b.invoice_id,
  o.name as organization,
  b.total_cents,
  b.paid_cents,
  -b.balance_cents as overpaid_cents
from billing.invoice_balances b
join billing.organizations o on o.id = b.org_id
where b.balance_cents < 0
order by overpaid_cents desc;

-- 4. Payment succeeded but the invoice is still 'open' (payment/invoice sync issue to escalate).
create or replace view billing.paid_but_open_invoices as
select
  b.invoice_id,
  o.name as organization,
  b.total_cents,
  b.paid_cents
from billing.invoice_balances b
join billing.organizations o on o.id = b.org_id
where b.status = 'open'
  and b.balance_cents <= 0
  and b.paid_cents > 0;

-- 5. Monthly failed-payment rate.
create or replace view billing.failed_payment_rate_monthly as
select
  date_trunc('month', created_at)::date                         as month,
  count(*)                                                      as attempts,
  count(*) filter (where status = 'failed')                     as failed,
  round(100.0 * count(*) filter (where status = 'failed') / count(*), 1) as failed_pct
from billing.payments
group by 1
order by 1;

-- 6. Why payments fail (helps write the right macro or doc).
create or replace view billing.failure_reasons as
select
  coalesce(failure_reason, 'unknown') as failure_reason,
  count(*)                            as failures
from billing.payments
where status = 'failed'
group by 1
order by failures desc;

-- 7. Organizations with 3+ failed payments in the last 30 days (churn / restriction risk).
create or replace view billing.repeat_payment_failures as
select
  o.id as org_id,
  o.name as organization,
  o.billing_email,
  count(*) as failed_last_30_days,
  max(p.created_at) as last_failure_at
from billing.payments p
join billing.invoices i on i.id = p.invoice_id
join billing.organizations o on o.id = i.org_id
where p.status = 'failed'
  and p.created_at >= now() - interval '30 days'
group by o.id, o.name, o.billing_email
having count(*) >= 3
order by failed_last_30_days desc;

-- 8. Paying EU organizations with no VAT ID on file (tax may be charged when reverse charge could apply).
create or replace view billing.eu_orgs_missing_vat_id as
select id as org_id, name as organization, billing_country, plan
from billing.organizations
where plan <> 'free'
  and tax_id is null
  and not tax_exempt
  and billing_country in ('AT','BE','BG','HR','CY','CZ','DK','EE','FI','FR','DE','GR','HU','IE',
                          'IT','LV','LT','LU','MT','NL','PL','PT','RO','SK','SI','ES','SE')
order by name;

-- 9. Tax charged to organizations marked tax-exempt (needs a tax correction / credit note).
create or replace view billing.tax_on_exempt_orgs as
select i.id as invoice_id, o.name as organization, i.tax_cents, i.period_start
from billing.invoices i
join billing.organizations o on o.id = i.org_id
where o.tax_exempt
  and i.tax_cents > 0
  and i.status <> 'void'
order by i.period_start desc;
