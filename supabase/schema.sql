create extension if not exists "pgcrypto";

-- =========================
-- ENUMS
-- =========================

create type user_role as enum (
  'buyer',
  'seller',
  'admin'
);

create type user_status as enum (
  'active',
  'suspended',
  'blocked'
);

create type shop_status as enum (
  'pending',
  'active',
  'suspended'
);

create type product_status as enum (
  'pending',
  'active',
  'inactive',
  'rejected'
);

create type transaction_status as enum (
  'awaiting_payment',
  'payment_review',
  'funds_received',
  'product_sent',
  'received',
  'dispute',
  'completed',
  'cancelled',
  'payout_pending',
  'paid_to_seller'
);

create type review_status as enum (
  'published',
  'hidden',
  'reported'
);

-- =========================
-- PROFILES
-- =========================

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  role user_role not null default 'buyer',
  status user_status not null default 'active',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- SHOPS
-- =========================

create table shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  name text not null,
  slug text not null unique,
  description text,
  logo_url text,
  status shop_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique(owner_id)
);

-- =========================
-- CATEGORIES
-- =========================

create table categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  created_at timestamptz not null default now()
);

-- =========================
-- PRODUCTS
-- =========================

create table products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  category_id uuid references categories(id) on delete set null,
  name text not null,
  slug text not null unique,
  description text,
  price bigint not null check (price >= 0),
  stock integer not null default 0 check (stock >= 0),
  image_url text,
  status product_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- TRANSACTIONS
-- =========================

create table transactions (
  id uuid primary key default gen_random_uuid(),
  transaction_code text not null unique,

  buyer_id uuid not null references profiles(id),
  seller_id uuid not null references profiles(id),
  product_id uuid not null references products(id),

  product_name text not null,
  quantity integer not null default 1 check (quantity > 0),

  subtotal bigint not null check (subtotal >= 0),
  tax bigint not null default 0 check (tax >= 0),
  total_amount bigint not null check (total_amount >= 0),

  status transaction_status not null default 'awaiting_payment',

  payment_proof_url text,
  shipping_proof_url text,

  buyer_note text,
  seller_note text,
  dispute_reason text,
  dispute_evidence_url text,

  payment_verified_at timestamptz,
  product_sent_at timestamptz,
  received_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  payout_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- TRANSACTION LOGS
-- =========================

create table transaction_logs (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references transactions(id) on delete cascade,
  actor_id uuid references profiles(id) on delete set null,
  action text not null,
  old_status transaction_status,
  new_status transaction_status,
  note text,
  evidence_url text,
  created_at timestamptz not null default now()
);

-- =========================
-- REVIEWS
-- =========================

create table reviews (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null unique references transactions(id) on delete cascade,
  buyer_id uuid not null references profiles(id) on delete cascade,
  seller_id uuid not null references profiles(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,

  rating integer not null check (rating between 1 and 5),
  comment text,
  status review_status not null default 'published',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- SELLER PAYOUT ACCOUNTS
-- =========================

create table seller_payout_accounts (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references profiles(id) on delete cascade,

  bank_name text not null,
  account_number text not null,
  account_holder text not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique(seller_id)
);

-- =========================
-- SITE SETTINGS
-- =========================

create table site_settings (
  id uuid primary key default gen_random_uuid(),

  bank_name text,
  bank_account_number text,
  bank_account_holder text,
  qris_image_url text,

  site_name text not null default 'Rayy Market',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- DEFAULT CATEGORIES
-- =========================

insert into categories (name, slug)
values
  ('Elektronik', 'elektronik'),
  ('Fashion', 'fashion'),
  ('Gaming', 'gaming'),
  ('Aksesoris', 'aksesoris'),
  ('Digital', 'digital'),
  ('Lainnya', 'lainnya')
on conflict (slug) do nothing;

-- =========================
-- DEFAULT SETTINGS
-- =========================

insert into site_settings (
  site_name
)
select 'Rayy Market'
where not exists (
  select 1 from site_settings
);

-- =========================
-- INDEXES
-- =========================

create index if not exists idx_shops_owner
on shops(owner_id);

create index if not exists idx_products_shop
on products(shop_id);

create index if not exists idx_products_category
on products(category_id);

create index if not exists idx_products_status
on products(status);

create index if not exists idx_transactions_buyer
on transactions(buyer_id);

create index if not exists idx_transactions_seller
on transactions(seller_id);

create index if not exists idx_transactions_status
on transactions(status);

create index if not exists idx_transaction_logs_transaction
on transaction_logs(transaction_id);

create index if not exists idx_reviews_seller
on reviews(seller_id);

-- =========================
-- UPDATED_AT FUNCTION
-- =========================

create or replace function update_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================
-- UPDATED_AT TRIGGERS
-- =========================

create trigger profiles_updated_at
before update on profiles
for each row
execute function update_updated_at();

create trigger shops_updated_at
before update on shops
for each row
execute function update_updated_at();

create trigger products_updated_at
before update on products
for each row
execute function update_updated_at();

create trigger transactions_updated_at
before update on transactions
for each row
execute function update_updated_at();

create trigger reviews_updated_at
before update on reviews
for each row
execute function update_updated_at();

create trigger seller_payout_accounts_updated_at
before update on seller_payout_accounts
for each row
execute function update_updated_at();

create trigger site_settings_updated_at
before update on site_settings
for each row
execute function update_updated_at();

-- =========================
-- CREATE PROFILE AFTER SIGNUP
-- =========================

create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    full_name
  )
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      'Pengguna Rayy Market'
    )
  );

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function handle_new_user();

-- =========================
-- ENABLE RLS
-- =========================

alter table profiles enable row level security;
alter table shops enable row level security;
alter table categories enable row level security;
alter table products enable row level security;
alter table transactions enable row level security;
alter table transaction_logs enable row level security;
alter table reviews enable row level security;
alter table seller_payout_accounts enable row level security;
alter table site_settings enable row level security;

-- =========================
-- PROFILE POLICIES
-- =========================

create policy "Users can view own profile"
on profiles
for select
to authenticated
using (id = auth.uid());

create policy "Users can update own profile"
on profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- =========================
-- CATEGORY POLICIES
-- =========================

create policy "Anyone can view categories"
on categories
for select
to anon, authenticated
using (true);

-- =========================
-- SHOP POLICIES
-- =========================

create policy "Anyone can view active shops"
on shops
for select
to anon, authenticated
using (status = 'active');

create policy "Seller can create own shop"
on shops
for insert
to authenticated
with check (
  owner_id = auth.uid()
);

create policy "Seller can update own shop"
on shops
for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

-- =========================
-- PRODUCT POLICIES
-- =========================

create policy "Anyone can view active products"
on products
for select
to anon, authenticated
using (status = 'active');

create policy "Seller can create own products"
on products
for insert
to authenticated
with check (
  exists (
    select 1
    from shops
    where shops.id = shop_id
    and shops.owner_id = auth.uid()
  )
);

create policy "Seller can update own products"
on products
for update
to authenticated
using (
  exists (
    select 1
    from shops
    where shops.id = shop_id
    and shops.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from shops
    where shops.id = shop_id
    and shops.owner_id = auth.uid()
  )
);

-- =========================
-- TRANSACTION POLICIES
-- =========================

create policy "Buyer or seller can view own transactions"
on transactions
for select
to authenticated
using (
  buyer_id = auth.uid()
  or seller_id = auth.uid()
);

create policy "Buyer can create transaction"
on transactions
for insert
to authenticated
with check (
  buyer_id = auth.uid()
);

-- =========================
-- TRANSACTION LOG POLICIES
-- =========================

create policy "Users can view transaction logs"
on transaction_logs
for select
to authenticated
using (
  exists (
    select 1
    from transactions
    where transactions.id = transaction_id
    and (
      transactions.buyer_id = auth.uid()
      or transactions.seller_id = auth.uid()
    )
  )
);

-- =========================
-- REVIEW POLICIES
-- =========================

create policy "Anyone can view published reviews"
on reviews
for select
to anon, authenticated
using (status = 'published');

create policy "Buyer can create review"
on reviews
for insert
to authenticated
with check (
  buyer_id = auth.uid()
);

create policy "Buyer can update own review"
on reviews
for update
to authenticated
using (buyer_id = auth.uid())
with check (buyer_id = auth.uid());

-- =========================
-- PAYOUT ACCOUNT POLICIES
-- =========================

create policy "Seller can view own payout account"
on seller_payout_accounts
for select
to authenticated
using (seller_id = auth.uid());

create policy "Seller can create own payout account"
on seller_payout_accounts
for insert
to authenticated
with check (seller_id = auth.uid());

create policy "Seller can update own payout account"
on seller_payout_accounts
for update
to authenticated
using (seller_id = auth.uid())
with check (seller_id = auth.uid());

-- =========================
-- SITE SETTINGS
-- =========================

create policy "Anyone can view site settings"
on site_settings
for select
to anon, authenticated
using (true);
