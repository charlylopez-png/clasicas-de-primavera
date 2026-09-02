-- UKT — Udaberriko Klasiko Txirrindulariak — esquema inicial
-- Ejecutar una vez contra la base de datos de Vercel Postgres (Neon):
--   psql "$DATABASE_URL" -f db/schema.sql

create extension if not exists pgcrypto;

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  password_hash text not null,
  display_name text not null,
  role text not null default 'participant' check (role in ('admin', 'participant')),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

create table if not exists riders (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null check (category in ('amarillo', 'rosa', 'verde')),
  multiplier numeric(3, 2) not null,
  created_at timestamptz not null default now()
);

create table if not exists races (
  id uuid primary key default gen_random_uuid(),
  order_num int not null unique,
  name text not null,
  stars int not null check (stars between 2 and 5),
  multiplier numeric(3, 2) not null,
  logo_path text,
  race_date date,
  created_at timestamptz not null default now()
);

-- Equipo Base: fijo para toda la temporada (6 corredores por participante:
-- 1 amarillo + 2 rosas + 3 verdes).
create table if not exists team_base (
  user_id uuid not null references users (id) on delete cascade,
  rider_id uuid not null references riders (id) on delete cascade,
  primary key (user_id, rider_id)
);

-- Last Draft: se recompone antes de cada carrera (6 corredores por
-- participante y carrera).
create table if not exists team_last_draft (
  user_id uuid not null references users (id) on delete cascade,
  race_id uuid not null references races (id) on delete cascade,
  rider_id uuid not null references riders (id) on delete cascade,
  primary key (user_id, race_id, rider_id)
);

-- Resultados oficiales: puesto de cada corredor en cada carrera (1-20).
create table if not exists race_results (
  race_id uuid not null references races (id) on delete cascade,
  rider_id uuid not null references riders (id) on delete cascade,
  position int not null check (position between 1 and 20),
  primary key (race_id, rider_id)
);

-- Duelos Sprint: un rival distinto por carrera, sorteado al inicio de
-- temporada.
create table if not exists sprint_pairings (
  race_id uuid not null references races (id) on delete cascade,
  user_a_id uuid not null references users (id) on delete cascade,
  user_b_id uuid not null references users (id) on delete cascade,
  winner_id uuid references users (id) on delete set null,
  primary key (race_id, user_a_id, user_b_id)
);

create index if not exists idx_team_last_draft_race on team_last_draft (race_id);
create index if not exists idx_race_results_race on race_results (race_id);
create index if not exists idx_sprint_pairings_race on sprint_pairings (race_id);

-- Calendario de las 12 clásicas (orden, estrellas, multiplicador y logo).
insert into races (order_num, name, stars, multiplier, logo_path) values
  (1, 'Omloop Het Nieuwsblad', 3, 1.5, '/logos/01-omloop-het-nieuwsblad.jpg'),
  (2, 'Strade Bianche', 4, 1.75, '/logos/02-strade-bianche.png'),
  (3, 'Milano-Sanremo', 5, 2, '/logos/03-milano-sanremo.png'),
  (4, 'Ronde van Brugge', 2, 1, '/logos/04-ronde-van-brugge.jpg'),
  (5, 'E3 Saxo Classic', 3, 1.5, '/logos/05-e3-saxo-classic.png'),
  (6, 'In Flanders Fields', 2, 1, '/logos/06-gent-wevelgem-in-flanders-fields.png'),
  (7, 'Dwars door Vlaanderen', 2, 1, '/logos/07-dwars-door-vlaanderen.png'),
  (8, 'Ronde van Vlaanderen', 5, 2, '/logos/08-ronde-van-vlaanderen.png'),
  (9, 'Paris-Roubaix', 5, 2, '/logos/09-paris-roubaix.png'),
  (10, 'Amstel Gold Race', 3, 1.5, '/logos/10-amstel-gold-race.png'),
  (11, 'La Flèche Wallonne', 3, 1.5, '/logos/11-la-fleche-wallonne.png'),
  (12, 'Liège-Bastogne-Liège', 5, 2, '/logos/12-liege-bastogne-liege.png')
on conflict (order_num) do nothing;
