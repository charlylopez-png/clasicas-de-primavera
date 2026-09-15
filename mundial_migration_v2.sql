-- Mundial de Montreal 2026 — ampliación: nombre de equipo por jugador.
-- No toca ninguna tabla existente. Seguro de re-ejecutar.

create table if not exists special_event_squads (
  event_id uuid not null references special_events (id) on delete cascade,
  user_id uuid not null references users (id) on delete cascade,
  team_name text not null default '',
  updated_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
