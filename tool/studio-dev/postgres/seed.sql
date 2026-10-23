-- The databases behind the Postgres seeds of tool/studio-dev/seed-connections.yaml.
-- NOT FOR PRODUCTION. Runs once, as the image's superuser, when the postgres service starts on an empty volume.
-- The passwords of app_owner and studio_reader are set by role-passwords.sh from the compose file, so neither is
-- written here.
--
-- app_owner owns every object, so Studio, signed in as it, sees the primary and foreign keys, which it reads from
-- information_schema views that show foreign keys only to the owner, and primary keys only to the owner or a role with
-- a non-SELECT privilege. studio_reader may only read, and seed:dev-postgres-readonly shows what Studio answers it.

CREATE ROLE app_owner LOGIN;
CREATE ROLE studio_reader LOGIN;
CREATE DATABASE app OWNER app_owner;
-- A second database, so the server-level seed lists more than one.
CREATE DATABASE archive OWNER app_owner;

\connect app
SET ROLE app_owner;

CREATE SCHEMA sales;

CREATE TABLE public.customers (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL,
  -- email and card_number are what the masking work of M4 (#32) masks.
  email text,
  card_number text,
  created_at timestamptz NOT NULL DEFAULT '2026-01-01 09:00:00+00'
);

CREATE TABLE public.orders (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id bigint NOT NULL REFERENCES public.customers (id),
  status text NOT NULL DEFAULT 'new',
  total numeric(20, 2),
  placed_at timestamptz,
  updated_at timestamptz,
  note text,
  details jsonb,
  receipt bytea
);
CREATE INDEX orders_customer_id_idx ON public.orders (customer_id);

CREATE TABLE public.order_items (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id bigint NOT NULL REFERENCES public.orders (id),
  sku text NOT NULL,
  quantity integer NOT NULL,
  unit_price numeric(10, 2) NOT NULL
);

-- One row of every column type the query result has to render (#32), read by query_types_postgres.json.
CREATE TABLE public.column_types (
  id integer PRIMARY KEY,
  small_value smallint,
  big_value bigint,
  numeric_value numeric(20, 6),
  real_value real,
  double_value double precision,
  bool_value boolean,
  text_value text,
  varchar_value varchar(20),
  char_value char(3),
  date_value date,
  time_value time,
  timestamp_value timestamp,
  timestamptz_value timestamptz,
  interval_value interval,
  uuid_value uuid,
  json_value json,
  jsonb_value jsonb,
  bytea_value bytea,
  int_array integer[],
  text_array text[],
  inet_value inet,
  null_value text
);

INSERT INTO public.customers (name, email, card_number) VALUES
  ('Ada Lovelace', 'ada@example.com', '4111111111111111'),
  ('Grace Hopper', 'grace@example.com', NULL),
  ('Linus Torvalds', NULL, NULL);

INSERT INTO public.orders (customer_id, status, total, placed_at, note, details, receipt) VALUES
  (1, 'paid', 120.50, '2026-03-01 10:15:00+00', 'Gift wrap', '{"channel": "web", "coupon": null}', '\x89504e47'),
  (1, 'new', NULL, NULL, NULL, NULL, NULL),
  (2, 'shipped', 9007199254740993.25, '2026-03-02 08:00:00+00', NULL, '{"channel": "store"}', NULL),
  (3, 'new', 0.10, NULL, NULL, NULL, NULL);

INSERT INTO public.order_items (order_id, sku, quantity, unit_price) VALUES
  (1, 'BOOK-001', 2, 40.25),
  (1, 'PEN-002', 1, 40.00),
  (3, 'LAPTOP-9', 1, 1999.99);

INSERT INTO public.column_types VALUES (
  1, 32767, 9007199254740993, 12345678901234.123456, 1.5, 3.141592653589793, true, 'text', 'varchar', 'abc',
  '2026-10-22', '13:45:00', '2026-10-22 13:45:00', '2026-10-22 13:45:00+00', '1 day 02:03:04',
  'a0000000-0000-4000-8000-000000000049', '{"a": [1, 2]}', '{"b": {"c": true}}', '\xdeadbeef', '{1,2,3}',
  '{"x","y"}', '192.0.2.1', NULL
);

CREATE VIEW sales.order_totals AS
  SELECT o.id AS order_id, c.name AS customer, o.status, coalesce(sum(i.quantity * i.unit_price), 0) AS items_total
  FROM public.orders o
  JOIN public.customers c ON c.id = o.customer_id
  LEFT JOIN public.order_items i ON i.order_id = o.id
  GROUP BY o.id, c.name, o.status;

CREATE FUNCTION sales.order_total(order_id bigint) RETURNS numeric
  LANGUAGE sql STABLE
  AS $$
    SELECT coalesce(sum(quantity * unit_price), 0) FROM public.order_items WHERE order_items.order_id = $1
  $$;

CREATE PROCEDURE sales.mark_shipped(order_id bigint)
  LANGUAGE plpgsql
  AS $$
  BEGIN
    UPDATE public.orders SET status = 'shipped' WHERE id = order_id;
  END
  $$;

CREATE FUNCTION public.touch_updated_at() RETURNS trigger
  LANGUAGE plpgsql
  AS $$
  BEGIN
    NEW.updated_at := now();
    RETURN NEW;
  END
  $$;

CREATE TRIGGER orders_touch_updated_at BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Exactly 100 rows, so pages of 50 give a page with more to come, a last full page and an empty one past it, read by
-- query_page_postgres_first.json, _second.json and _third.json. In sales, so no answer recorded from public changes.
CREATE TABLE sales.ledger (
  id integer PRIMARY KEY,
  entry text NOT NULL
);
INSERT INTO sales.ledger SELECT n, 'entry ' || n FROM generate_series(1, 100) AS n;

-- One exclusion constraint, which the Indexes tab lists under its own heading, recorded as
-- describe_postgres_room_bookings.json. In sales, so no answer recorded from public changes.
CREATE TABLE sales.room_bookings (
  id integer PRIMARY KEY,
  room text NOT NULL,
  during tstzrange NOT NULL,
  EXCLUDE USING gist (during WITH &&)
);

GRANT USAGE ON SCHEMA public, sales TO studio_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public, sales TO studio_reader;

\connect archive
SET ROLE app_owner;

CREATE TABLE public.orders_2025 (
  id bigint PRIMARY KEY,
  customer text NOT NULL,
  total numeric(12, 2)
);
INSERT INTO public.orders_2025 VALUES (1, 'Ada Lovelace', 80.00), (2, 'Grace Hopper', NULL);

GRANT SELECT ON ALL TABLES IN SCHEMA public TO studio_reader;
