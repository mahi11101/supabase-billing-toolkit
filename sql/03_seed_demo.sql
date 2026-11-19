-- Supabase Billing Toolkit: demo data (fictional companies) to try the views.
-- Each case is designed to show up in exactly one health-check view.

truncate billing.credit_notes, billing.payments, billing.invoices,
         billing.projects, billing.organizations restart identity cascade;

insert into billing.organizations (name, plan, billing_email, billing_country, tax_id, tax_exempt, spend_cap_enabled) values
  ('Acme Analytics',   'pro',  'billing@acme.example',    'DE', null,          false, true),   -- 1: EU, no VAT ID
  ('Nimbus Labs',      'team', 'finance@nimbus.example',  'FR', 'FR12345678901', false, false), -- 2: overdue invoice
  ('Kite Studio',      'pro',  'owner@kite.example',      'IN', '29ABCDE1234F1Z5', false, true), -- 3: duplicate charge
  ('Orbit Nonprofit',  'pro',  'ops@orbit.example',       'US', null,          true,  true),   -- 4: exempt but taxed
  ('Pebble Apps',      'pro',  'dev@pebble.example',      'GB', 'GB123456789', false, true),   -- 5: repeat failures
  ('Quartz Data',      'pro',  'ap@quartz.example',       'NL', 'NL123456789B01', false, true); -- 6: paid but still open

insert into billing.projects (org_id, name, compute_size, status) values
  (1, 'acme-prod', 'micro', 'active'), (1, 'acme-staging', 'micro', 'active'), (1, 'acme-old', 'micro', 'paused'),
  (2, 'nimbus-api', 'medium', 'active'),
  (3, 'kite-web', 'micro', 'active'),
  (4, 'orbit-donations', 'small', 'active'),
  (5, 'pebble-mobile', 'micro', 'active'),
  (6, 'quartz-warehouse', 'large', 'active');

insert into billing.invoices (org_id, period_start, period_end, amount_cents, tax_cents, status, due_date, paid_at) values
  (1, current_date - 30, current_date, 3500, 665,  'paid', current_date - 2,  now() - interval '2 days'),  -- 1
  (2, current_date - 60, current_date - 30, 66900, 13380, 'open', current_date - 21, null),             -- 2 overdue
  (3, current_date - 30, current_date, 2500, 450,  'paid', current_date - 1,  now() - interval '1 day'),   -- 3 duplicate
  (4, current_date - 30, current_date, 3000, 240,  'paid', current_date - 3,  now() - interval '3 days'),  -- 4 taxed exempt
  (5, current_date - 30, current_date, 2500, 500,  'open', current_date - 2,  null),                      -- 5 failing
  (6, current_date - 30, current_date, 12600, 2646, 'open', current_date - 1, null);                      -- 6 paid, open

insert into billing.payments (invoice_id, amount_cents, status, failure_reason, created_at) values
  (1, 4165,  'succeeded', null,                 now() - interval '2 days'),
  (2, 80280, 'failed',    'insufficient_funds', now() - interval '20 days'),
  (3, 2950,  'succeeded', null,                 now() - interval '1 day'),
  (3, 2950,  'succeeded', null,                 now() - interval '1 day' + interval '2 minutes'),  -- duplicate
  (4, 3240,  'succeeded', null,                 now() - interval '3 days'),
  (5, 3000,  'failed',    'card_declined',      now() - interval '6 days'),
  (5, 3000,  'failed',    'card_declined',      now() - interval '4 days'),
  (5, 3000,  'failed',    'expired_card',       now() - interval '2 days'),
  (6, 15246, 'succeeded', null,                 now() - interval '1 day');
