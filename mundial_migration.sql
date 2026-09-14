-- Mundial de Montreal 2026: prueba única y separada de la porra de
-- clásicas. Tablas propias — no tocan riders/races/team_base/team_last_draft,
-- así que no afectan a la categorización ni a la clasificación general.
-- Seguro de re-ejecutar.

create table if not exists special_events (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  event_date date,
  picks_lock_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists special_event_riders (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references special_events (id) on delete cascade,
  name text not null,
  team text,
  category text not null default 'verde' check (category in ('amarillo', 'rosa', 'verde')),
  multiplier numeric(3, 2) not null default 2.00,
  created_at timestamptz not null default now(),
  unique (event_id, name)
);

-- La elección de cada jugador para el Mundial: 6 filas por (event_id, user_id).
create table if not exists special_event_picks (
  event_id uuid not null references special_events (id) on delete cascade,
  user_id uuid not null references users (id) on delete cascade,
  rider_id uuid not null references special_event_riders (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id, rider_id)
);

-- Resultado oficial: puesto de cada corredor de la lista cerrada (1-20).
-- Un corredor de la lista que no aparece aquí se entiende que no puntuó.
create table if not exists special_event_results (
  event_id uuid not null references special_events (id) on delete cascade,
  rider_id uuid not null references special_event_riders (id) on delete cascade,
  position int not null check (position between 1 and 20),
  primary key (event_id, rider_id)
);

create index if not exists idx_special_event_riders_event on special_event_riders (event_id);
create index if not exists idx_special_event_picks_event_user on special_event_picks (event_id, user_id);

-- Evento: Mundial de Montreal 2026. Prueba en línea élite masculina el
-- 27/9/2026; fichajes cerrados antes de que arranque la semana del Mundial.
insert into special_events (slug, name, event_date, picks_lock_at)
values (
  'montreal-2026',
  'Mundial de Montreal 2026',
  '2026-09-27',
  '2026-09-19 23:59:00+02'
)
on conflict (slug) do update
set
  name = excluded.name,
  event_date = excluded.event_date,
  picks_lock_at = excluded.picks_lock_at;
