-- Supabase Billing Toolkit: example billing schema for Postgres / Supabase
-- A minimal, realistic model of SaaS billing: organizations, projects,
-- invoices, payments and credit notes. Amounts are stored in cents.

create schema if not exists billing;

create table if not exists billing.organizations (
  id                bigint generated always as identity primary key,
  name              text not null,
  plan              text not null check (plan in ('free', 'pro', 'team', 'enterprise')),
  billing_email     text,
  billing_country   char(2) not null,            -- ISO 3166-1 alpha-2, e.g. 'DE', 'IN', 'US'
  tax_id            text,                        -- VAT ID, GSTIN, EIN, ABN ...
  tax_exempt        boolean not null default false,
  spend_cap_enabled boolean not null default true,
  created_at        timestamptz not null default now()
);

create table if not exists billing.projects (
  id            bigint generated always as identity primary key,
  org_id        bigint not null references billing.organizations(id) on delete cascade,
  name          text not null,
  compute_size  text not null default 'micro',
  status        text not null default 'active' check (status in ('active', 'paused', 'deleted')),
  created_at    timestamptz not null default now()
);

create table if not exists billing.invoices (
  id            bigint generated always as identity primary key,
  org_id        bigint not null references billing.organizations(id) on delete cascade,
  period_start  date not null,
  period_end    date not null,
  amount_cents  integer not null check (amount_cents >= 0),   -- before tax
  tax_cents     integer not null default 0 check (tax_cents >= 0),
  status        text not null check (status in ('draft', 'open', 'paid', 'void', 'uncollectible')),
  due_date      date not null,
  paid_at       timestamptz,
  created_at    timestamptz not null default now()
);

create table if not exists billing.payments (
  id             bigint generated always as identity primary key,
  invoice_id     bigint not null references billing.invoices(id) on delete cascade,
  amount_cents   integer not null check (amount_cents > 0),
  status         text not null check (status in ('succeeded', 'failed', 'refunded')),
  failure_reason text,                       -- e.g. 'card_declined', 'insufficient_funds', 'expired_card'
  created_at     timestamptz not null default now()
);

create table if not exists billing.credit_notes (
  id           bigint generated always as identity primary key,
  invoice_id   bigint not null references billing.invoices(id) on delete cascade,
  amount_cents integer not null check (amount_cents > 0),
  reason       text not null,                -- e.g. 'goodwill', 'duplicate_charge', 'tax_correction'
  created_at   timestamptz not null default now()
);

create index if not exists invoices_org_status_idx on billing.invoices (org_id, status);
create index if not exists payments_invoice_idx    on billing.payments (invoice_id);
create index if not exists payments_created_idx    on billing.payments (created_at);
