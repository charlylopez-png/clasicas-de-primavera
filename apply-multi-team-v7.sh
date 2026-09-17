#!/usr/bin/env bash
set -euo pipefail

# apply-multi-team-v7.sh — cada jugador puede tener más de un equipo,
# tanto en las clásicas (Equipo Base + Last Draft de cada carrera) como
# en el Mundial. Cada equipo es una entrada independiente y completa: su
# propia Equipo Base, su propio fichaje por carrera, su propia elección
# del Mundial. Se puede crear cuantos equipos se quiera, sin límite, con
# el botón "+ Nuevo equipo" que aparece ahora en esas pantallas.
#
# IMPORTANTE: hay que ejecutar un .sql en Neon —
# db/multi_team_migration.sql — que:
#   - crea la tabla `teams`,
#   - le crea a cada jugador ya existente un primer equipo (reutilizando
#     el nombre que ya tuviera puesto en el Mundial, si lo tenía), y
#   - re-engancha a ese equipo TODAS las fichas ya guardadas (Equipo
#     Base, Last Draft de cada carrera, elección del Mundial) — no se
#     pierde nada.
# Es seguro de re-ejecutar.
#
# Ejecuta esto DESDE LA RAÍZ del repo (donde está db/schema.sql), con el
# Codespace ya abierto. Requiere haber aplicado antes apply-mundial-v6.sh.

if [ ! -f "db/schema.sql" ]; then
  echo "Error: no se encuentra db/schema.sql en el directorio actual."
  echo "Ejecuta este script desde la raíz del repo clasicas-de-primavera."
  exit 1
fi

echo "Aplicando varios equipos por jugador (v7)..."

echo "  - src/lib/teams.ts"
mkdir -p "src/lib"
cat > "src/lib/teams.ts" <<'UKT_MULTI_TEAM_V7_EOF'
import { cookies } from "next/headers";
import { sql } from "./db";

// Un jugador puede tener más de un equipo (tanto en las clásicas como en
// el Mundial): cada uno es una entrada independiente en la porra, con su
// propio Equipo Base, su propio Last Draft por carrera y su propia
// elección del Mundial. `teams` es la entidad que representa cada una de
// esas entradas; `users` sigue siendo solo la cuenta con la que se
// inicia sesión.

export const ACTIVE_TEAM_COOKIE = "ukt_active_team";
export const DEFAULT_TEAM_NAME = "Mi equipo";
export const TEAM_NAME_MAX_LEN = 60;

export type Team = {
  id: string;
  name: string;
  user_id: string;
};

export async function getUserTeams(userId: string): Promise<Team[]> {
  return (await sql`
    select id, name, user_id
    from teams
    where user_id = ${userId}
    order by created_at
  `) as Team[];
}

export async function createTeam(userId: string, name: string): Promise<Team> {
  const trimmed = name.trim().slice(0, TEAM_NAME_MAX_LEN) || DEFAULT_TEAM_NAME;
  const [team] = (await sql`
    insert into teams (user_id, name)
    values (${userId}, ${trimmed})
    returning id, name, user_id
  `) as Team[];
  return team;
}

// El equipo "activo": el que marca la cookie, si de verdad pertenece a
// este usuario, o si no el más antiguo de los suyos. Si por lo que sea
// todavía no tuviera ninguno (no debería pasar tras la migración), se le
// crea uno al vuelo para no romper ninguna pantalla.
export async function resolveActiveTeam(
  userId: string,
  teams: Team[]
): Promise<Team> {
  if (teams.length === 0) {
    return createTeam(userId, DEFAULT_TEAM_NAME);
  }
  const store = await cookies();
  const activeId = store.get(ACTIVE_TEAM_COOKIE)?.value;
  return teams.find((t) => t.id === activeId) ?? teams[0];
}

// Conveniencia para páginas/rutas que solo necesitan el equipo activo (la
// mayoría): junta getUserTeams + resolveActiveTeam en una sola llamada.
export async function getActiveTeam(userId: string): Promise<{
  teams: Team[];
  activeTeam: Team;
}> {
  const teams = await getUserTeams(userId);
  const activeTeam = await resolveActiveTeam(userId, teams);
  return { teams, activeTeam };
}

export async function setActiveTeamCookie(teamId: string) {
  const store = await cookies();
  store.set(ACTIVE_TEAM_COOKIE, teamId, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 30,
  });
}
UKT_MULTI_TEAM_V7_EOF

echo "  - src/app/api/teams/route.ts"
mkdir -p "src/app/api/teams"
cat > "src/app/api/teams/route.ts" <<'UKT_MULTI_TEAM_V7_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { getSession } from "@/lib/auth";
import { createTeam, setActiveTeamCookie, TEAM_NAME_MAX_LEN } from "@/lib/teams";

const BodySchema = z.object({
  name: z.string().trim().min(1).max(TEAM_NAME_MAX_LEN),
});

// Crea un nuevo equipo para el usuario de la sesión actual (o, con
// "Actuar como", para el jugador suplantado) y lo deja como equipo
// activo. No hay límite de equipos por jugador.
export async function POST(request: Request) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "No autorizado." }, { status: 401 });
  }
  if (session.role !== "admin" && session.status !== "approved") {
    return NextResponse.json({ error: "Tu cuenta todavía no está aprobada." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "Ponle un nombre al equipo (máximo 60 caracteres)." },
      { status: 400 }
    );
  }

  const team = await createTeam(session.userId, parsed.data.name);
  await setActiveTeamCookie(team.id);

  return NextResponse.json({ ok: true, team });
}
UKT_MULTI_TEAM_V7_EOF

echo "  - src/app/api/teams/switch/route.ts"
mkdir -p "src/app/api/teams/switch"
cat > "src/app/api/teams/switch/route.ts" <<'UKT_MULTI_TEAM_V7_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { getSession } from "@/lib/auth";
import { getUserTeams, setActiveTeamCookie } from "@/lib/teams";

const BodySchema = z.object({
  teamId: z.string().uuid(),
});

// Cambia cuál es el equipo "activo" (el que se edita en Equipo Base, Last
// Draft y Mundial) entre los del propio usuario de la sesión.
export async function POST(request: Request) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "No autorizado." }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Falta el equipo al que cambiar." }, { status: 400 });
  }

  const teams = await getUserTeams(session.userId);
  const team = teams.find((t) => t.id === parsed.data.teamId);
  if (!team) {
    return NextResponse.json({ error: "Ese equipo no es tuyo." }, { status: 403 });
  }

  await setActiveTeamCookie(team.id);
  return NextResponse.json({ ok: true });
}
UKT_MULTI_TEAM_V7_EOF

echo "  - src/components/team-switcher.tsx"
mkdir -p "src/components"
cat > "src/components/team-switcher.tsx" <<'UKT_MULTI_TEAM_V7_EOF'
"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

export type TeamOption = { id: string; name: string };

// Selector de equipo: aparece en Equipo Base, Last Draft y Mundial para
// que un jugador con más de un equipo pueda cambiar de cuál está
// editando, y crear equipos nuevos sin límite.
export default function TeamSwitcher({
  teams,
  activeTeamId,
}: {
  teams: TeamOption[];
  activeTeamId: string;
}) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState("");
  const [error, setError] = useState<string | null>(null);

  function switchTo(teamId: string) {
    if (teamId === activeTeamId || isPending) return;
    setError(null);
    startTransition(async () => {
      const res = await fetch("/api/teams/switch", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ teamId }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => null);
        setError(data?.error ?? "No se pudo cambiar de equipo.");
        return;
      }
      router.refresh();
    });
  }

  function createTeam() {
    const name = newName.trim();
    if (!name || isPending) return;
    setError(null);
    startTransition(async () => {
      const res = await fetch("/api/teams", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setError(data?.error ?? "No se pudo crear el equipo.");
        return;
      }
      setCreating(false);
      setNewName("");
      router.refresh();
    });
  }

  return (
    <div className="mb-4">
      {teams.length > 1 && (
        <p className="mb-1.5 text-[11px] text-text-soft">
          Tienes {teams.length} equipos — este cambio afecta solo al que
          tengas abierto ahora.
        </p>
      )}
      <div className="flex flex-wrap items-center gap-1.5">
        {teams.map((team) => (
          <button
            key={team.id}
            type="button"
            disabled={isPending}
            onClick={() => switchTo(team.id)}
            aria-pressed={team.id === activeTeamId}
            className={`rounded-full px-3 py-1.5 text-xs font-semibold transition disabled:opacity-50 ${
              team.id === activeTeamId
                ? "bg-verde-deep text-on-accent"
                : "border border-line bg-surface text-text-soft hover:border-verde-deep/50"
            }`}
          >
            {team.name}
          </button>
        ))}

        {creating ? (
          <div className="flex items-center gap-1.5">
            <input
              type="text"
              autoFocus
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") createTeam();
                if (e.key === "Escape") {
                  setCreating(false);
                  setNewName("");
                }
              }}
              maxLength={60}
              placeholder="Nombre del equipo nuevo"
              className="rounded-full border border-line bg-surface px-3 py-1.5 text-xs outline-none focus:border-verde"
            />
            <button
              type="button"
              disabled={!newName.trim() || isPending}
              onClick={createTeam}
              className="rounded-full bg-amarillo px-3 py-1.5 text-xs font-semibold text-on-accent disabled:opacity-40"
            >
              Crear
            </button>
            <button
              type="button"
              onClick={() => {
                setCreating(false);
                setNewName("");
              }}
              className="text-xs text-text-soft underline underline-offset-2"
            >
              Cancelar
            </button>
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setCreating(true)}
            className="rounded-full border border-dashed border-line px-3 py-1.5 text-xs text-verde-deep hover:border-verde-deep"
          >
            + Nuevo equipo
          </button>
        )}
      </div>
      {error && <p className="mt-1.5 text-xs text-rosa">{error}</p>}
    </div>
  );
}
UKT_MULTI_TEAM_V7_EOF

echo "  - src/app/mi-equipo/page.tsx"
mkdir -p "src/app/mi-equipo"
cat > "src/app/mi-equipo/page.tsx" <<'UKT_MULTI_TEAM_V7_EOF'
import Link from "next/link";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getActiveTeam } from "@/lib/teams";
import SquadSelector, { type SelectableRider } from "@/components/squad-selector";
import TeamSwitcher from "@/components/team-switcher";
import type { RiderCategory } from "@/lib/riders";

type RaceRow = {
  order_num: number;
  name: string;
};

type DraftPick = {
  order_num: number;
  name: string;
  category: RiderCategory;
};

export default async function MiEquipoPage() {
  const session = await getSession();
  if (!session) return null; // el proxy ya redirige a /login antes de llegar aquí

  const { teams, activeTeam } = await getActiveTeam(session.userId);

  const riders = (await sql`
    select id, name, team, division, category
    from riders
    order by division, team, name
  `) as SelectableRider[];

  const teamBase = (await sql`
    select rider_id from team_base where team_id = ${activeTeam.id}
  `) as { rider_id: string }[];

  const races = (await sql`
    select order_num, name from races order by order_num
  `) as RaceRow[];

  const picks = (await sql`
    select r.order_num, ri.name, ri.category
    from team_last_draft tld
    join races r on r.id = tld.race_id
    join riders ri on ri.id = tld.rider_id
    where tld.team_id = ${activeTeam.id}
    order by r.order_num, ri.category
  `) as DraftPick[];

  const picksByRace = new Map<number, DraftPick[]>();
  for (const p of picks) {
    if (!picksByRace.has(p.order_num)) picksByRace.set(p.order_num, []);
    picksByRace.get(p.order_num)!.push(p);
  }

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Tu plantilla
      </div>
      <h1 className="text-2xl text-verde-deep">
        Hola, {session.displayName}
      </h1>

      <div className="mt-4">
        <TeamSwitcher teams={teams} activeTeamId={activeTeam.id} />
      </div>

      <section className="mt-8">
        <h2 className="font-display text-sm text-verde-deep">Equipo Base</h2>
        <p className="mt-1 text-sm text-text-soft">
          6 corredores fijos para toda la temporada: 1 Amarillo, 2 Rosas y 3
          Verdes. Si el Sanedrín todavía no ha clasificado a nadie fuera de
          Verde, espera a que lo haga antes de poder completar el equipo.
        </p>
        <div className="mt-4 rounded-2xl bg-surface p-4">
          <SquadSelector
            key={activeTeam.id}
            riders={riders}
            initialSelectedIds={teamBase.map((r) => r.rider_id)}
            saveUrl="/api/team-base"
          />
        </div>
      </section>

      <section className="mt-10 pb-6">
        <h2 className="font-display text-sm text-verde-deep">
          Fichajes por carrera
        </h2>
        <p className="mt-1 text-sm text-text-soft">
          El Last Draft se elige carrera a carrera, desde la página de cada
          una. Aquí solo ves el resumen.
        </p>
        <div className="mt-4 flex flex-col gap-2">
          {races.map((race) => {
            const racePicks = picksByRace.get(race.order_num) ?? [];
            return (
              <Link
                key={race.order_num}
                href={`/calendario/${race.order_num}`}
                className="flex items-center justify-between gap-3 rounded-xl border border-line bg-surface px-4 py-3 hover:border-verde-deep/50"
              >
                <div className="min-w-0">
                  <div className="font-display text-[11px] text-text-soft">
                    {String(race.order_num).padStart(2, "0")}
                  </div>
                  <div className="truncate text-sm font-semibold">{race.name}</div>
                </div>
                {racePicks.length === 6 ? (
                  <span className="shrink-0 rounded-full bg-verde px-2.5 py-1 text-[11px] font-semibold text-on-accent">
                    Fichado ✓
                  </span>
                ) : (
                  <span className="shrink-0 rounded-full border border-line px-2.5 py-1 text-[11px] text-text-soft">
                    Sin fichar
                  </span>
                )}
              </Link>
            );
          })}
        </div>
      </section>
    </div>
  );
}
UKT_MULTI_TEAM_V7_EOF

echo "  - src/app/api/team-base/route.ts"
mkdir -p "src/app/api/team-base"
cat > "src/app/api/team-base/route.ts" <<'UKT_MULTI_TEAM_V7_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql, transaction } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getActiveTeam } from "@/lib/teams";
import { isValidSquad, SQUAD_SIZE, type RiderCategory } from "@/lib/riders";

const BodySchema = z.object({
  riderIds: z.array(z.string().uuid()).length(SQUAD_SIZE),
});

export async function POST(request: Request) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "No autorizado." }, { status: 401 });
  }
  if (session.role !== "admin" && session.status !== "approved") {
    return NextResponse.json({ error: "Tu cuenta todavía no está aprobada." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: `El Equipo Base debe tener exactamente ${SQUAD_SIZE} corredores.` },
      { status: 400 }
    );
  }

  const riderIds = Array.from(new Set(parsed.data.riderIds));
  if (riderIds.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Hay corredores repetidos en la selección." },
      { status: 400 }
    );
  }

  const rows = (await sql`
    select id, category from riders where id = any(${riderIds}::uuid[])
  `) as { id: string; category: RiderCategory }[];

  if (rows.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Alguno de los corredores seleccionados ya no existe." },
      { status: 400 }
    );
  }

  if (!isValidSquad(rows.map((r) => r.category))) {
    return NextResponse.json(
      { error: "El Equipo Base debe ser 1 Amarillo + 2 Rosas + 3 Verdes." },
      { status: 400 }
    );
  }

  const { activeTeam } = await getActiveTeam(session.userId);

  await transaction([
    sql`delete from team_base where team_id = ${activeTeam.id}`,
    sql`
      insert into team_base (team_id, rider_id)
      select ${activeTeam.id}::uuid, unnest(${riderIds}::uuid[])
    `,
  ]);

  return NextResponse.json({ ok: true });
}
UKT_MULTI_TEAM_V7_EOF

echo "  - src/app/calendario/[order]/page.tsx"
mkdir -p "src/app/calendario/[order]"
cat > "src/app/calendario/[order]/page.tsx" <<'UKT_MULTI_TEAM_V7_EOF'
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getActiveTeam } from "@/lib/teams";
import { formatCoefficient, formatRaceDate } from "@/lib/riders";
import SquadSelector, { type SelectableRider } from "@/components/squad-selector";
import TeamSwitcher from "@/components/team-switcher";

type Race = {
  id: string;
  order_num: number;
  name: string;
  stars: number;
  multiplier: string | number;
  logo_path: string;
  race_date: string | Date | null;
  official_url: string | null;
};

type HistoryRow = {
  position: number;
  rider_name: string;
  team: string | null;
};

const DARK_TILE_ORDERS = new Set([9]);
const HISTORY_YEAR = 2026;

export default async function RaceDetailPage({
  params,
}: {
  params: Promise<{ order: string }>;
}) {
  const { order } = await params;
  const orderNum = Number(order);
  if (!Number.isInteger(orderNum)) notFound();

  const races = (await sql`
    select id, order_num, name, stars, multiplier, logo_path, race_date, official_url
    from races
    where order_num = ${orderNum}
  `) as Race[];
  const race = races[0];
  if (!race) notFound();

  const history = (await sql`
    select position, rider_name, team
    from race_results_history
    where race_id = ${race.id} and edition_year = ${HISTORY_YEAR}
    order by position
  `) as HistoryRow[];

  const session = await getSession();
  const canDraft = Boolean(session && (session.role === "admin" || session.status === "approved"));

  let riders: SelectableRider[] = [];
  let initialSelectedIds: string[] = [];
  let teams: { id: string; name: string }[] = [];
  let activeTeamId = "";
  if (canDraft && session) {
    const active = await getActiveTeam(session.userId);
    teams = active.teams;
    activeTeamId = active.activeTeam.id;

    riders = (await sql`
      select id, name, team, division, category
      from riders
      order by division, team, name
    `) as SelectableRider[];
    const picks = (await sql`
      select rider_id from team_last_draft
      where team_id = ${activeTeamId} and race_id = ${race.id}
    `) as { rider_id: string }[];
    initialSelectedIds = picks.map((p) => p.rider_id);
  }

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <Link href="/calendario" className="text-xs text-text-soft hover:text-verde-deep">
        ← Calendario
      </Link>

      <div className="mt-3 flex items-center gap-4">
        <div
          className={`h-20 w-20 shrink-0 overflow-hidden rounded-2xl border-2 border-white ${
            DARK_TILE_ORDERS.has(race.order_num) ? "bg-[var(--hero-bg-1)]" : "bg-white"
          }`}
        >
          <Image
            src={race.logo_path}
            alt={race.name}
            width={80}
            height={80}
            className="h-full w-full object-cover"
          />
        </div>
        <div className="min-w-0">
          <div className="font-display text-[11px] text-text-soft">
            Carrera {String(race.order_num).padStart(2, "0")} de 12
          </div>
          <h1 className="text-2xl text-verde-deep">{race.name}</h1>
          <div className="mt-1 flex items-center gap-3">
            <span className="text-amarillo" aria-label={`${race.stars} estrellas`}>
              {"★".repeat(race.stars)}
              <span className="text-line">{"★".repeat(5 - race.stars)}</span>
            </span>
            <span className="rounded-full bg-rosa px-2.5 py-1 font-display text-[11px] font-semibold text-on-accent">
              {formatCoefficient(race.multiplier)}
            </span>
          </div>
        </div>
      </div>

      <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-text-soft">
        <span>{race.race_date ? formatRaceDate(race.race_date) : "Fecha por confirmar."}</span>
        {race.official_url && (
          <a
            href={race.official_url}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-verde-deep underline underline-offset-2"
          >
            Web oficial ↗
          </a>
        )}
      </div>

      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        <div className="rounded-2xl border border-dashed border-line bg-surface p-4">
          <h2 className="font-display text-xs uppercase tracking-wide text-verde-deep">
            Perfil de la carrera
          </h2>
          <p className="mt-1.5 text-[13px] leading-relaxed text-text-soft">
            Pendiente de añadir (recorrido, desnivel, tipo de llegada…).
          </p>
        </div>
        <div className="rounded-2xl border border-dashed border-line bg-surface p-4">
          <h2 className="font-display text-xs uppercase tracking-wide text-verde-deep">
            Participantes
          </h2>
          <p className="mt-1.5 text-[13px] leading-relaxed text-text-soft">
            Pendiente de añadir el pelotón inscrito en esta carrera.
          </p>
        </div>
      </div>

      {history.length > 0 && (
        <section className="mt-8">
          <h2 className="font-display text-sm text-verde-deep">
            Edición {HISTORY_YEAR}
          </h2>
          <p className="mt-1 text-sm text-text-soft">
            {history[0] && (
              <>
                Ganador: <b className="text-verde-deep">{history[0].rider_name}</b>
                {history[0].team ? ` (${history[0].team})` : ""}.
              </>
            )}
          </p>
          <div className="mt-3 overflow-hidden rounded-2xl border border-line bg-surface">
            <ol className="divide-y divide-line">
              {history.map((row) => (
                <li
                  key={row.position}
                  className={`flex items-center gap-3 px-4 py-2 text-sm ${
                    row.position === 1 ? "bg-amarillo/20" : ""
                  }`}
                >
                  <span
                    className={`w-6 shrink-0 text-right font-display text-xs ${
                      row.position === 1 ? "text-amarillo" : "text-text-soft"
                    }`}
                  >
                    {row.position}
                  </span>
                  <span className="min-w-0 flex-1 truncate">
                    {row.rider_name}
                    {row.position === 1 && " 🏆"}
                  </span>
                  {row.team && (
                    <span className="shrink-0 truncate text-xs text-text-soft">
                      {row.team}
                    </span>
                  )}
                </li>
              ))}
            </ol>
          </div>
          {history.length < 20 && (
            <p className="mt-2 text-[11px] text-text-soft">
              De momento solo hay {history.length} posiciones confirmadas de esta
              edición.
            </p>
          )}
        </section>
      )}

      <section className="mt-10 pb-6">
        <h2 className="font-display text-sm text-verde-deep">
          Tu fichaje para esta carrera
        </h2>
        <p className="mt-1 text-sm text-text-soft">
          Last Draft: 1 Amarillo, 2 Rosas y 3 Verdes, solo para esta carrera.
        </p>

        {canDraft ? (
          <div className="mt-4 rounded-2xl bg-surface p-4">
            <TeamSwitcher teams={teams} activeTeamId={activeTeamId} />
            <SquadSelector
              key={activeTeamId}
              riders={riders}
              initialSelectedIds={initialSelectedIds}
              saveUrl={`/api/races/${race.id}/draft`}
            />
          </div>
        ) : (
          <div className="mt-4 rounded-2xl border border-dashed border-line bg-surface p-6 text-center text-sm text-text-soft">
            {session ? (
              "Tu cuenta todavía no está aprobada."
            ) : (
              <>
                <Link href="/login" className="text-verde-deep underline">
                  Inicia sesión
                </Link>{" "}
                para fichar tu equipo de esta carrera.
              </>
            )}
          </div>
        )}
      </section>
    </div>
  );
}
UKT_MULTI_TEAM_V7_EOF

echo "  - src/app/api/races/[id]/draft/route.ts"
mkdir -p "src/app/api/races/[id]/draft"
cat > "src/app/api/races/[id]/draft/route.ts" <<'UKT_MULTI_TEAM_V7_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql, transaction } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getActiveTeam } from "@/lib/teams";
import { isValidSquad, SQUAD_SIZE, type RiderCategory } from "@/lib/riders";

const BodySchema = z.object({
  riderIds: z.array(z.string().uuid()).length(SQUAD_SIZE),
});

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "No autorizado." }, { status: 401 });
  }
  if (session.role !== "admin" && session.status !== "approved") {
    return NextResponse.json({ error: "Tu cuenta todavía no está aprobada." }, { status: 403 });
  }

  const { id: raceId } = await params;
  const race = await sql`select id from races where id = ${raceId}`;
  if (race.length === 0) {
    return NextResponse.json({ error: "Esa carrera no existe." }, { status: 404 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: `El fichaje debe tener exactamente ${SQUAD_SIZE} corredores.` },
      { status: 400 }
    );
  }

  const riderIds = Array.from(new Set(parsed.data.riderIds));
  if (riderIds.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Hay corredores repetidos en la selección." },
      { status: 400 }
    );
  }

  const rows = (await sql`
    select id, category from riders where id = any(${riderIds}::uuid[])
  `) as { id: string; category: RiderCategory }[];

  if (rows.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Alguno de los corredores seleccionados ya no existe." },
      { status: 400 }
    );
  }

  if (!isValidSquad(rows.map((r) => r.category))) {
    return NextResponse.json(
      { error: "El fichaje debe ser 1 Amarillo + 2 Rosas + 3 Verdes." },
      { status: 400 }
    );
  }

  const { activeTeam } = await getActiveTeam(session.userId);

  await transaction([
    sql`delete from team_last_draft where team_id = ${activeTeam.id} and race_id = ${raceId}`,
    sql`
      insert into team_last_draft (team_id, race_id, rider_id)
      select ${activeTeam.id}::uuid, ${raceId}::uuid, unnest(${riderIds}::uuid[])
    `,
  ]);

  return NextResponse.json({ ok: true });
}
UKT_MULTI_TEAM_V7_EOF

echo "  - src/app/mundial/eleccion/page.tsx"
mkdir -p "src/app/mundial/eleccion"
cat > "src/app/mundial/eleccion/page.tsx" <<'UKT_MULTI_TEAM_V7_EOF'
import { getSession } from "@/lib/auth";
import { sql } from "@/lib/db";
import { getActiveTeam } from "@/lib/teams";
import MundialSquadSelector, {
  type MundialRider,
} from "@/components/mundial-squad-selector";
import TeamSwitcher from "@/components/team-switcher";
import { getMundialEvent, isPicksLocked } from "@/lib/mundial";

export default async function MundialEleccionPage() {
  const session = await getSession();
  if (!session) return null; // el proxy ya redirige a /login antes de llegar aquí

  const event = await getMundialEvent();
  if (!event) {
    return (
      <p className="text-sm text-text-soft">
        Todavía no se ha configurado esta prueba especial.
      </p>
    );
  }

  const locked = isPicksLocked(event.picks_lock_at);
  const { teams, activeTeam } = await getActiveTeam(session.userId);

  const riders = (await sql`
    select id, name, team, category
    from special_event_riders
    where event_id = ${event.id}
    order by team, name
  `) as MundialRider[];

  const picks = (await sql`
    select rider_id from special_event_picks
    where event_id = ${event.id} and team_id = ${activeTeam.id}
  `) as { rider_id: string }[];

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Elección de equipo</h2>
      <p className="mt-1 text-sm text-text-soft">
        Ponle un nombre a tu equipo y elige 6 corredores de la lista cerrada: 1
        Amarillo, 2 Rosas y 3 Verdes. Puedes cambiarlo cuantas veces quieras
        hasta la fecha límite.
      </p>

      <div className="mt-4 rounded-2xl bg-surface p-4">
        <TeamSwitcher teams={teams} activeTeamId={activeTeam.id} />
        {riders.length === 0 ? (
          <p className="text-sm text-text-soft">
            Todavía no hay lista de corredores para esta prueba.
          </p>
        ) : (
          <MundialSquadSelector
            key={activeTeam.id}
            riders={riders}
            initialSelectedIds={picks.map((p) => p.rider_id)}
            initialTeamName={activeTeam.name}
            locked={locked}
          />
        )}
      </div>
    </section>
  );
}
UKT_MULTI_TEAM_V7_EOF

echo "  - src/app/mundial/equipo/page.tsx"
mkdir -p "src/app/mundial/equipo"
cat > "src/app/mundial/equipo/page.tsx" <<'UKT_MULTI_TEAM_V7_EOF'
import Link from "next/link";
import { getSession } from "@/lib/auth";
import { sql } from "@/lib/db";
import { getActiveTeam } from "@/lib/teams";
import { getMundialEvent, isPicksLocked, pointsForPosition } from "@/lib/mundial";
import MundialTeamEditor, {
  type MundialRider,
} from "@/components/mundial-team-editor";
import TeamSwitcher from "@/components/team-switcher";

type PickRow = {
  rider_id: string;
  multiplier: string;
  position: number | null;
};

export default async function MundialEquipoPage() {
  const session = await getSession();
  if (!session) return null; // el proxy ya redirige a /login antes de llegar aquí

  const event = await getMundialEvent();
  if (!event) {
    return (
      <p className="text-sm text-text-soft">
        Todavía no se ha configurado esta prueba especial.
      </p>
    );
  }

  const locked = isPicksLocked(event.picks_lock_at);
  const { teams, activeTeam } = await getActiveTeam(session.userId);

  const riders = (await sql`
    select id, name, team, category
    from special_event_riders
    where event_id = ${event.id}
    order by team, name
  `) as MundialRider[];

  const picks = (await sql`
    select p.rider_id, r.multiplier, res.position
    from special_event_picks p
    join special_event_riders r on r.id = p.rider_id
    left join special_event_results res
      on res.event_id = p.event_id and res.rider_id = p.rider_id
    where p.event_id = ${event.id} and p.team_id = ${activeTeam.id}
  `) as PickRow[];

  const total = picks.reduce(
    (sum, p) => sum + pointsForPosition(p.position) * Number(p.multiplier),
    0
  );

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Mi equipo</h2>

      <div className="mt-4">
        <TeamSwitcher teams={teams} activeTeamId={activeTeam.id} />
      </div>

      {picks.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-line bg-surface p-6 text-center text-sm text-text-soft">
          Todavía no has fichado a nadie.{" "}
          <Link href="/mundial/eleccion" className="text-verde-deep underline">
            Elige tu equipo
          </Link>
          .
        </div>
      ) : (
        <div className="rounded-2xl bg-surface p-4">
          <div className="flex items-center justify-between gap-3">
            <p className="text-xs text-text-soft">{session.displayName}</p>
            <span className="font-display text-lg text-amarillo">
              {total.toFixed(1)} pts
            </span>
          </div>

          <div className="mt-4">
            <MundialTeamEditor
              key={activeTeam.id}
              riders={riders}
              initialSelectedIds={picks.map((p) => p.rider_id)}
              initialTeamName={activeTeam.name}
              locked={locked}
            />
          </div>
        </div>
      )}
    </section>
  );
}
UKT_MULTI_TEAM_V7_EOF

echo "  - src/app/api/mundial/picks/route.ts"
mkdir -p "src/app/api/mundial/picks"
cat > "src/app/api/mundial/picks/route.ts" <<'UKT_MULTI_TEAM_V7_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql, transaction } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getActiveTeam } from "@/lib/teams";
import { isValidSquad, SQUAD_SIZE, MUNDIAL_SLUG, type RiderCategory } from "@/lib/mundial";

const BodySchema = z.object({
  riderIds: z.array(z.string().uuid()).length(SQUAD_SIZE),
  teamName: z.string().trim().min(1).max(60),
});

export async function POST(request: Request) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "No autorizado." }, { status: 401 });
  }
  if (session.role !== "admin" && session.status !== "approved") {
    return NextResponse.json({ error: "Tu cuenta todavía no está aprobada." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      {
        error: `Ponle un nombre a tu equipo y elige exactamente ${SQUAD_SIZE} corredores.`,
      },
      { status: 400 }
    );
  }

  const events = await sql`
    select id, picks_lock_at from special_events where slug = ${MUNDIAL_SLUG}
  `;
  const event = events[0];
  if (!event) {
    return NextResponse.json({ error: "No se encuentra el evento del Mundial." }, { status: 500 });
  }
  if (event.picks_lock_at && new Date(event.picks_lock_at).getTime() <= Date.now()) {
    return NextResponse.json(
      { error: "Los fichajes para el Mundial ya están cerrados." },
      { status: 403 }
    );
  }

  const riderIds = Array.from(new Set(parsed.data.riderIds));
  if (riderIds.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Hay corredores repetidos en la selección." },
      { status: 400 }
    );
  }

  const rows = (await sql`
    select id, category from special_event_riders
    where event_id = ${event.id} and id = any(${riderIds}::uuid[])
  `) as { id: string; category: RiderCategory }[];

  if (rows.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Alguno de los corredores seleccionados ya no existe." },
      { status: 400 }
    );
  }

  if (!isValidSquad(rows.map((r) => r.category))) {
    return NextResponse.json(
      { error: "El equipo debe ser 1 Amarillo + 2 Rosas + 3 Verdes." },
      { status: 400 }
    );
  }

  const { activeTeam } = await getActiveTeam(session.userId);

  await transaction([
    sql`delete from special_event_picks where event_id = ${event.id} and team_id = ${activeTeam.id}`,
    sql`
      insert into special_event_picks (event_id, team_id, rider_id)
      select ${event.id}::uuid, ${activeTeam.id}::uuid, unnest(${riderIds}::uuid[])
    `,
    sql`update teams set name = ${parsed.data.teamName} where id = ${activeTeam.id}`,
  ]);

  return NextResponse.json({ ok: true });
}
UKT_MULTI_TEAM_V7_EOF

echo "  - src/app/mundial/clasificacion/page.tsx"
mkdir -p "src/app/mundial/clasificacion"
cat > "src/app/mundial/clasificacion/page.tsx" <<'UKT_MULTI_TEAM_V7_EOF'
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getUserTeams } from "@/lib/teams";
import { getMundialEvent, isPicksLocked, pointsForPosition } from "@/lib/mundial";
import CountryFlag from "@/components/country-flag";

type SquadRow = {
  team_id: string;
  display_name: string;
  team_name: string;
};

type PickRow = {
  team_id: string;
  rider_name: string;
  team: string | null;
  multiplier: string;
  position: number | null;
};

export default async function MundialClasificacionPage() {
  const session = await getSession();
  if (!session) return null; // el proxy ya redirige a /login antes de llegar aquí

  const event = await getMundialEvent();
  if (!event) {
    return (
      <p className="text-sm text-text-soft">
        Todavía no se ha configurado esta prueba especial.
      </p>
    );
  }

  const locked = isPicksLocked(event.picks_lock_at);

  // Un jugador puede tener varios equipos, y cada uno cuenta como una
  // entrada independiente en esta clasificación (no hay tabla de
  // "squads" del Mundial: basta con los equipos que ya tienen algún
  // fichaje guardado para este evento).
  const squadRows = (await sql`
    select distinct t.id as team_id, t.name as team_name, u.display_name
    from special_event_picks p
    join teams t on t.id = p.team_id
    join users u on u.id = t.user_id
    where p.event_id = ${event.id}
    order by u.display_name
  `) as SquadRow[];

  const pickRows = (await sql`
    select
      p.team_id,
      r.name as rider_name,
      r.team,
      r.multiplier,
      res.position
    from special_event_picks p
    join special_event_riders r on r.id = p.rider_id
    left join special_event_results res
      on res.event_id = p.event_id and res.rider_id = p.rider_id
    where p.event_id = ${event.id}
  `) as PickRow[];

  const picksByTeam = new Map<string, PickRow[]>();
  for (const row of pickRows) {
    if (!picksByTeam.has(row.team_id)) picksByTeam.set(row.team_id, []);
    picksByTeam.get(row.team_id)!.push(row);
  }

  // Todos los equipos propios (no solo el activo ahora mismo) se
  // consideran "míos" a efectos de ver los corredores antes del cierre.
  const myTeamIds = new Set((await getUserTeams(session.userId)).map((t) => t.id));

  const standings = squadRows
    .map((s) => {
      const picks = picksByTeam.get(s.team_id) ?? [];
      const total = picks.reduce(
        (sum, p) => sum + pointsForPosition(p.position) * Number(p.multiplier),
        0
      );
      return {
        teamId: s.team_id,
        displayName: s.display_name,
        teamName: s.team_name || "(sin nombre)",
        total,
        picks,
      };
    })
    .sort((a, b) => b.total - a.total);

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Clasificación</h2>
      <p className="mt-1 text-sm text-text-soft">
        Independiente de la clasificación general de las clásicas.
        {!locked && (
          <>
            {" "}
            Mientras los fichajes estén abiertos, solo se ve el nombre de cada
            equipo — los corredores elegidos se revelan al cerrarse el plazo.
          </>
        )}
      </p>

      <div className="mt-6 flex flex-col gap-3">
        {standings.map((s, i) => {
          const revealed = locked || myTeamIds.has(s.teamId);
          return (
            <div
              key={s.teamId}
              className="rounded-2xl border border-line bg-surface p-4"
            >
              <div className="flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <span className="font-display text-sm text-verde-deep">
                    {i + 1}. {s.teamName}
                  </span>
                  <div className="text-[11px] text-text-soft">{s.displayName}</div>
                </div>
                <span className="shrink-0 font-display text-lg text-amarillo">
                  {s.total.toFixed(1)}
                </span>
              </div>
              {revealed ? (
                <div className="mt-2 flex flex-wrap gap-1.5 text-xs text-text-soft">
                  {s.picks.map((p, j) => (
                    <span key={j} className="rounded-full border border-line px-2.5 py-1">
                      <CountryFlag team={p.team} className="mr-1" />
                      {p.rider_name} · {(pointsForPosition(p.position) * Number(p.multiplier)).toFixed(1)}
                    </span>
                  ))}
                </div>
              ) : (
                <p className="mt-2 text-[11px] text-text-faint">
                  Equipo oculto hasta que se cierren los fichajes.
                </p>
              )}
            </div>
          );
        })}
        {standings.length === 0 && (
          <p className="text-sm text-text-soft">
            Todavía no hay fichajes registrados para esta prueba.
          </p>
        )}
      </div>
    </section>
  );
}
UKT_MULTI_TEAM_V7_EOF

echo "  - src/app/api/admin/manual-players/[id]/route.ts"
mkdir -p "src/app/api/admin/manual-players/[id]"
cat > "src/app/api/admin/manual-players/[id]/route.ts" <<'UKT_MULTI_TEAM_V7_EOF'
import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";

// Solo borra si is_manual = true, para que este endpoint no pueda usarse
// nunca para eliminar una cuenta real por error. El borrado en cascada ya
// existente (teams referencia users, y team_base/team_last_draft/
// special_event_picks referencian teams, todo con ON DELETE CASCADE)
// limpia también sus equipos, sus fichajes y su elección del Mundial.
export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const { id } = await params;
  const rows = await sql`
    delete from users where id = ${id} and is_manual = true
    returning id
  `;
  if (!rows[0]) {
    return NextResponse.json(
      { error: "No se encuentra ese jugador manual." },
      { status: 404 }
    );
  }

  return NextResponse.json({ ok: true });
}
UKT_MULTI_TEAM_V7_EOF


echo ""
echo "Archivos escritos. Creando commit..."
git add -A
git commit -m "Permite que cada jugador tenga más de un equipo

Añade la tabla teams como la entidad real de \"equipo\": antes cada
jugador solo podía tener uno, implícito en su propia cuenta. Ahora se
pueden crear equipos adicionales sin límite (botón + Nuevo equipo), tanto
para las clásicas (Equipo Base y Last Draft por carrera) como para el
Mundial, cada uno con sus propias fichas y su propia elección,
independiente del resto. La clasificación del Mundial ahora lista cada
equipo por separado."
git push

echo ""
echo "Archivos aplicados. AHORA ejecuta en el editor SQL de Neon:"
echo "  db/multi_team_migration.sql"
echo "(Crea la tabla teams, migra todas las fichas existentes a un primer"
echo "equipo por jugador, y no pierde ningún fichaje ya guardado.)"
