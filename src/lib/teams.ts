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
