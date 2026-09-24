-- =========================================================
-- RAYY MARKET
-- Supabase PostgreSQL Database Schema
-- V1
-- =========================================================

create extension if not exists "pgcrypto";


-- =========================================================
-- ENUM TYPES
-- =========================================================

do $$
begin
    create type public.user_role as enum (
        'buyer',
        'seller',
        'admin'
    );
exception
    when duplicate_object then null;
end $$;


do $$
begin
    create type public.user_status as enum (
        'active',
        'suspended',
        'blocked'
    );
exception
    when duplicate_object then null;
end $$;


do $$
begin
    create type public.shop_status as enum (
        'pending',
        'active',
        'suspended'
    );
exception
    when duplicate_object then null;
end $$;


do $$
begin
    create type public.product_status as enum (
        'pending',
        'active',
        'inactive',
        'rejected'
    );
exception
    when duplicate_object then null;
end $$;


do $$
begin
    create type public.transaction_status as enum (
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
exception
    when duplicate_object then null;
end $$;


do $$
begin
    create type public.review_status as enum (
        'published',
        'hidden',
        'reported'
    );
exception
    when duplicate_object then null;
end $$;


-- =========================================================
-- PROFILES
-- Terhubung dengan Supabase Auth
-- =========================================================

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,

    name varchar(100) not null,

    phone varchar(30),

    role public.user_role not null default 'buyer',

    status public.user_status not null default 'active',

    avatar_url text,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()
);


-- =========================================================
-- SHOPS
-- =========================================================

create table if not exists public.shops (
    id uuid primary key default gen_random_uuid(),

    seller_id uuid not null unique
        references public.profiles(id)
        on delete cascade,

    shop_name varchar(150) not null,

    description text,

    logo_url text,

    rating_average numeric(3,2) not null default 0.00,

    rating_count integer not null default 0,

    status public.shop_status not null default 'pending',

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()
);


-- =========================================================
-- CATEGORIES
-- =========================================================

create table if not exists public.categories (
    id uuid primary key default gen_random_uuid(),

    name varchar(100) not null unique,

    slug varchar(120) not null unique,

    status boolean not null default true,

    created_at timestamptz not null default now()
);


-- =========================================================
-- PRODUCTS
-- =========================================================

create table if not exists public.products (
    id uuid primary key default gen_random_uuid(),

    shop_id uuid not null
        references public.shops(id)
        on delete cascade,

    category_id uuid
        references public.categories(id)
        on delete set null,

    name varchar(200) not null,

    slug varchar(220) not null unique,

    description text,

    price numeric(15,2) not null default 0,

    stock integer not null default 0,

    image_url text,

    status public.product_status not null default 'pending',

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint products_price_check
        check (price >= 0),

    constraint products_stock_check
        check (stock >= 0)
);


-- =========================================================
-- TRANSACTIONS
-- =========================================================

create table if not exists public.transactions (
    id uuid primary key default gen_random_uuid(),

    transaction_code varchar(40) not null unique,

    buyer_id uuid not null
        references public.profiles(id)
        on delete restrict,

    seller_id uuid not null
        references public.profiles(id)
        on delete restrict,

    product_id uuid not null
        references public.products(id)
        on delete restrict,

    shop_id uuid not null
        references public.shops(id)
        on delete restrict,

    product_name varchar(200) not null,

    quantity integer not null default 1,

    price numeric(15,2) not null default 0,

    subtotal numeric(15,2) not null default 0,

    service_fee numeric(15,2) not null default 0,

    grand_total numeric(15,2) not null default 0,

    status public.transaction_status not null
        default 'awaiting_payment',

    -- Bukti pembayaran buyer
    payment_proof_url text,

    payment_uploaded_at timestamptz,

    payment_verified_at timestamptz,

    payment_verified_by uuid
        references public.profiles(id)
        on delete set null,

    -- Bukti produk dikirim seller
    shipping_proof_url text,

    shipped_at timestamptz,

    -- Buyer menerima produk
    received_at timestamptz,

    -- Buyer menyelesaikan transaksi
    completed_at timestamptz,

    -- Komplain
    dispute_reason text,

    dispute_evidence_url text,

    dispute_created_at timestamptz,

    -- Payout seller
    payout_amount numeric(15,2),

    payout_proof_url text,

    payout_at timestamptz,

    payout_by uuid
        references public.profiles(id)
        on delete set null,

    -- Pembatalan
    cancelled_reason text,

    cancelled_at timestamptz,

    cancelled_by uuid
        references public.profiles(id)
        on delete set null,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint transactions_quantity_check
        check (quantity > 0),

    constraint transactions_price_check
        check (price >= 0),

    constraint transactions_subtotal_check
        check (subtotal >= 0),

    constraint transactions_service_fee_check
        check (service_fee >= 0),

    constraint transactions_grand_total_check
        check (grand_total >= 0)
);


-- =========================================================
-- TRANSACTION LOGS
-- Semua perubahan transaksi dicatat
-- =========================================================

create table if not exists public.transaction_logs (
    id bigint generated by default as identity primary key,

    transaction_id uuid not null
        references public.transactions(id)
        on delete cascade,

    user_id uuid
        references public.profiles(id)
        on delete set null,

    action varchar(100) not null,

    description text,

    old_status varchar(50),

    new_status varchar(50),

    created_at timestamptz not null default now()
);


-- =========================================================
-- REVIEWS / RATING
-- =========================================================

create table if not exists public.reviews (
    id uuid primary key default gen_random_uuid(),

    transaction_id uuid not null unique
        references public.transactions(id)
        on delete cascade,

    buyer_id uuid not null
        references public.profiles(id)
        on delete restrict,

    seller_id uuid not null
        references public.profiles(id)
        on delete restrict,

    product_id uuid not null
        references public.products(id)
        on delete restrict,

    rating integer not null,

    comment text,

    status public.review_status not null default 'published',

    seller_report text,

    admin_note text,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint reviews_rating_check
        check (rating between 1 and 5)
);


-- =========================================================
-- SELLER PAYOUT ACCOUNT
-- Rekening untuk pencairan manual oleh admin
-- =========================================================

create table if not exists public.seller_payout_accounts (
    id uuid primary key default gen_random_uuid(),

    seller_id uuid not null unique
        references public.profiles(id)
        on delete cascade,

    bank_name varchar(100),

    account_number varchar(100),

    account_name varchar(150),

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now()
);


-- =========================================================
-- SITE SETTINGS
-- Pengaturan rekening/QRIS admin
-- =========================================================

create table if not exists public.site_settings (
    id uuid primary key default gen_random_uuid(),

    setting_key varchar(100) not null unique,

    setting_value text,

    updated_at timestamptz not null default now()
);


-- =========================================================
-- INDEXES
-- =========================================================

create index if not exists idx_profiles_role
on public.profiles(role);


create index if not exists idx_profiles_status
on public.profiles(status);


create index if not exists idx_shops_seller
on public.shops(seller_id);


create index if not exists idx_shops_status
on public.shops(status);


create index if not exists idx_products_shop
on public.products(shop_id);


create index if not exists idx_products_category
on public.products(category_id);


create index if not exists idx_products_status
on public.products(status);


create index if not exists idx_products_name
on public.products(name);


create index if not exists idx_transactions_buyer
on public.transactions(buyer_id);


create index if not exists idx_transactions_seller
on public.transactions(seller_id);


create index if not exists idx_transactions_product
on public.transactions(product_id);


create index if not exists idx_transactions_shop
on public.transactions(shop_id);


create index if not exists idx_transactions_status
on public.transactions(status);


create index if not exists idx_transactions_created
on public.transactions(created_at);


create index if not exists idx_transaction_logs_transaction
on public.transaction_logs(transaction_id);


create index if not exists idx_transaction_logs_created
on public.transaction_logs(created_at);


create index if not exists idx_reviews_seller
on public.reviews(seller_id);


create index if not exists idx_reviews_product
on public.reviews(product_id);


create index if not exists idx_reviews_status
on public.reviews(status);


-- =========================================================
-- DEFAULT CATEGORIES
-- =========================================================

insert into public.categories (name, slug)
values
    ('Elektronik', 'elektronik'),
    ('Fashion', 'fashion'),
    ('Aksesoris', 'aksesoris'),
    ('Gaming', 'gaming'),
    ('Pulsa & Data', 'pulsa-data'),
    ('Voucher', 'voucher'),
    ('Digital', 'digital'),
    ('Lainnya', 'lainnya')
on conflict (slug) do nothing;


-- =========================================================
-- DEFAULT SETTINGS
-- =========================================================

insert into public.site_settings (setting_key, setting_value)
values
    ('site_name', 'Rayy Market'),

    ('admin_bank_name', ''),

    ('admin_bank_account', ''),

    ('admin_bank_owner', ''),

    ('admin_qris_image', ''),

    ('transaction_fee', '0'),

    ('contact_whatsapp', ''),

    (
        'transaction_rules',
        'Pembayaran hanya dilakukan melalui rekening atau QRIS yang tampil pada halaman transaksi resmi Rayy Market.'
    ),

    (
        'dispute_rules',
        'Komplain wajib disertai alasan yang jelas dan bukti pendukung.'
    )
on conflict (setting_key) do nothing;


-- =========================================================
-- FUNCTION:
-- Membuat profile otomatis setelah user register
-- =========================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

    insert into public.profiles (
        id,
        name,
        phone,
        role
    )
    values (
        new.id,
        coalesce(
            new.raw_user_meta_data ->> 'name',
            'User'
        ),
        new.raw_user_meta_data ->> 'phone',
        'buyer'
    );

    return new;

end;
$$;


-- =========================================================
-- TRIGGER:
-- Jalankan profile otomatis ketika user dibuat
-- =========================================================

drop trigger if exists on_auth_user_created
on auth.users;


create trigger on_auth_user_created

after insert on auth.users

for each row

execute procedure public.handle_new_user();


-- =========================================================
-- FUNCTION:
-- Update updated_at otomatis
-- =========================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin

    new.updated_at = now();

    return new;

end;
$$;


-- =========================================================
-- TRIGGERS updated_at
-- =========================================================

drop trigger if exists profiles_updated_at
on public.profiles;

create trigger profiles_updated_at
before update on public.profiles
for each row
execute procedure public.set_updated_at();


drop trigger if exists shops_updated_at
on public.shops;

create trigger shops_updated_at
before update on public.shops
for each row
execute procedure public.set_updated_at();


drop trigger if exists products_updated_at
on public.products;

create trigger products_updated_at
before update on public.products
for each row
execute procedure public.set_updated_at();


drop trigger if exists transactions_updated_at
on public.transactions;

create trigger transactions_updated_at
before update on public.transactions
for each row
execute procedure public.set_updated_at();


drop trigger if exists reviews_updated_at
on public.reviews;

create trigger reviews_updated_at
before update on public.reviews
for each row
execute procedure public.set_updated_at();


drop trigger if exists payout_accounts_updated_at
on public.seller_payout_accounts;

create trigger payout_accounts_updated_at
before update on public.seller_payout_accounts
for each row
execute procedure public.set_updated_at();


drop trigger if exists site_settings_updated_at
on public.site_settings;

create trigger site_settings_updated_at
before update on public.site_settings
for each row
execute procedure public.set_updated_at();


-- =========================================================
-- SELESAI
-- =========================================================
