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
