import { redirect } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getMundialEvent, pointsForPosition } from "@/lib/mundial";
import MundialTeamsManager, { type MundialTeamRow } from "@/components/mundial-teams-manager";

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

export default async function MundialEquiposPage() {
  const session = await getSession();
  if (!session) redirect("/login");
  if (session.role !== "admin") redirect("/mundial");

  const event = await getMundialEvent();
  if (!event) {
    return (
      <p className="text-sm text-text-soft">
        Todavía no se ha configurado esta prueba especial.
      </p>
    );
  }

  // A diferencia de la Clasificación pública, aquí el admin ve siempre
  // todos los corredores fichados por cada equipo, esté abierto o cerrado
  // el plazo -- para poder gestionar bien qué equipo quitar.
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

  const teams: MundialTeamRow[] = squadRows
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
        picks: picks.map((p) => ({
          riderName: p.rider_name,
          team: p.team,
          points: pointsForPosition(p.position) * Number(p.multiplier),
        })),
      };
    })
    .sort((a, b) => a.displayName.localeCompare(b.displayName));

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Equipos del Mundial</h2>
      <p className="mt-1 max-w-prose text-sm text-text-soft">
        Todos los equipos fichados para esta prueba, sea cual sea el estado
        del plazo. Quitar un equipo de aquí solo borra su fichaje del
        Mundial — nunca toca sus equipos de las clásicas.
      </p>

      <MundialTeamsManager teams={teams} />
    </section>
  );
}
