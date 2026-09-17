#!/usr/bin/env bash
set -euo pipefail

# apply-team-unique-names-v8.sh — cada equipo tiene que tener un nombre
# distinto de los DEMÁS EQUIPOS DEL MISMO JUGADOR (no hace falta que sea
# distinto entre jugadores distintos: dos personas pueden llamar a su
# equipo igual sin problema). Si se intenta repetir un nombre ya usado
# por otro equipo propio, se avisa con un mensaje claro y no se guarda.
#
# IMPORTANTE: hay que ejecutar un .sql en Neon —
# db/team_unique_names_migration.sql — que añade el índice único
# correspondiente (y, por si acaso ya hubiera algún duplicado de antes,
# lo renombra automáticamente antes de imponerlo). Seguro de re-ejecutar.
#
# Ejecuta esto DESDE LA RAÍZ del repo (donde está db/schema.sql), con el
# Codespace ya abierto. Requiere haber aplicado antes apply-multi-team-v7.sh.

if [ ! -f "db/schema.sql" ]; then
  echo "Error: no se encuentra db/schema.sql en el directorio actual."
  echo "Ejecuta este script desde la raíz del repo clasicas-de-primavera."
  exit 1
fi

echo "Aplicando nombres de equipo únicos por jugador (v8)..."

echo "  - src/lib/teams.ts"
mkdir -p "src/lib"
cat > "src/lib/teams.ts" <<'UKT_TEAM_NAMES_V8_EOF'
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

// Cada jugador elige el nombre de cada uno de sus equipos, y tiene que
// ser distinto de los demás equipos SUYOS (no hace falta que sea único
// entre jugadores distintos: dos personas pueden llamar a su equipo
// igual sin problema). Se comprueba a nivel de aplicación para dar un
// mensaje claro, y además hay un índice único en la base de datos como
// red de seguridad por si dos peticiones llegan a la vez.
export class DuplicateTeamNameError extends Error {}

function isUniqueViolation(err: unknown): boolean {
  return Boolean(err && typeof err === "object" && "code" in err && err.code === "23505");
}

export async function getUserTeams(userId: string): Promise<Team[]> {
  return (await sql`
    select id, name, user_id
    from teams
    where user_id = ${userId}
    order by created_at
  `) as Team[];
}

async function assertNameAvailable(userId: string, name: string, excludeTeamId?: string) {
  const existing = (await sql`
    select id from teams
    where user_id = ${userId} and lower(name) = lower(${name})
      and id <> ${excludeTeamId ?? "00000000-0000-0000-0000-000000000000"}
  `) as { id: string }[];
  if (existing.length > 0) {
    throw new DuplicateTeamNameError(`Ya tienes un equipo llamado "${name}". Elige otro nombre.`);
  }
}

export async function createTeam(userId: string, name: string): Promise<Team> {
  const trimmed = name.trim().slice(0, TEAM_NAME_MAX_LEN) || DEFAULT_TEAM_NAME;
  await assertNameAvailable(userId, trimmed);
  try {
    const [team] = (await sql`
      insert into teams (user_id, name)
      values (${userId}, ${trimmed})
      returning id, name, user_id
    `) as Team[];
    return team;
  } catch (err) {
    if (isUniqueViolation(err)) {
      throw new DuplicateTeamNameError(`Ya tienes un equipo llamado "${trimmed}". Elige otro nombre.`);
    }
    throw err;
  }
}

// Renombra un equipo ya existente (se usa, por ejemplo, al guardar el
// nombre de equipo desde las pantallas del Mundial).
export async function renameTeam(
  teamId: string,
  userId: string,
  name: string
): Promise<void> {
  const trimmed = name.trim().slice(0, TEAM_NAME_MAX_LEN) || DEFAULT_TEAM_NAME;
  await assertNameAvailable(userId, trimmed, teamId);
  try {
    await sql`update teams set name = ${trimmed} where id = ${teamId} and user_id = ${userId}`;
  } catch (err) {
    if (isUniqueViolation(err)) {
      throw new DuplicateTeamNameError(`Ya tienes un equipo llamado "${trimmed}". Elige otro nombre.`);
    }
    throw err;
  }
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
UKT_TEAM_NAMES_V8_EOF

echo "  - src/app/api/teams/route.ts"
mkdir -p "src/app/api/teams"
cat > "src/app/api/teams/route.ts" <<'UKT_TEAM_NAMES_V8_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { getSession } from "@/lib/auth";
import {
  createTeam,
  setActiveTeamCookie,
  DuplicateTeamNameError,
  TEAM_NAME_MAX_LEN,
} from "@/lib/teams";

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

  try {
    const team = await createTeam(session.userId, parsed.data.name);
    await setActiveTeamCookie(team.id);
    return NextResponse.json({ ok: true, team });
  } catch (err) {
    if (err instanceof DuplicateTeamNameError) {
      return NextResponse.json({ error: err.message }, { status: 409 });
    }
    throw err;
  }
}
UKT_TEAM_NAMES_V8_EOF

echo "  - src/app/api/mundial/picks/route.ts"
mkdir -p "src/app/api/mundial/picks"
cat > "src/app/api/mundial/picks/route.ts" <<'UKT_TEAM_NAMES_V8_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql, transaction } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getActiveTeam, renameTeam, DuplicateTeamNameError } from "@/lib/teams";
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

  try {
    await renameTeam(activeTeam.id, session.userId, parsed.data.teamName);
  } catch (err) {
    if (err instanceof DuplicateTeamNameError) {
      return NextResponse.json({ error: err.message }, { status: 409 });
    }
    throw err;
  }

  await transaction([
    sql`delete from special_event_picks where event_id = ${event.id} and team_id = ${activeTeam.id}`,
    sql`
      insert into special_event_picks (event_id, team_id, rider_id)
      select ${event.id}::uuid, ${activeTeam.id}::uuid, unnest(${riderIds}::uuid[])
    `,
  ]);

  return NextResponse.json({ ok: true });
}
UKT_TEAM_NAMES_V8_EOF


echo ""
echo "Archivos escritos. Creando commit..."
git add -A
git commit -m "Cada equipo debe tener un nombre distinto de los demás equipos propios

Al crear o renombrar un equipo, ya no se puede repetir el nombre de otro
equipo del mismo jugador (sí se puede repetir el de un equipo de otra
persona). Se avisa con un mensaje claro si se intenta."
git push

echo ""
echo "Archivos aplicados. AHORA ejecuta en el editor SQL de Neon:"
echo "  db/team_unique_names_migration.sql"
echo "(Añade el índice único; si hubiera algún duplicado de antes, lo"
echo "renombra automáticamente en vez de fallar.)"
