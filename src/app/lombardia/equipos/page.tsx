import { redirect } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getLombardiaEvent, pointsForPosition } from "@/lib/lombardia";
import LombardiaTeamsManager, { type LombardiaTeamRow } from "@/components/lombardia-teams-manager";

type SquadRow = {
  team_id: string;
  display_name: string;
  team_name: string;
};

type PickRow = {
  team_id: string;
  rider_name: string;
  team: string | null;
  nationality: string | null;
  multiplier: string;
  position: number | null;
};

export default async function LombardiaEquiposPage() {
  const session = await getSession();
  if (!session) redirect("/login");
  if (session.role !== "admin") redirect("/lombardia");

  const event = await getLombardiaEvent();
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
      r.nationality,
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

  const teams: LombardiaTeamRow[] = squadRows
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
          nationality: p.nationality,
          points: pointsForPosition(p.position) * Number(p.multiplier),
        })),
      };
    })
    .sort((a, b) => a.displayName.localeCompare(b.displayName));

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Equipos de Il Lombardia</h2>
      <p className="mt-1 max-w-prose text-sm text-text-soft">
        Todos los equipos fichados para esta prueba, sea cual sea el estado
        del plazo. Quitar un equipo de aquí solo borra su fichaje del
        Il Lombardia — nunca toca sus equipos de las clásicas, del Mundial ni
        del Europeo.
      </p>

      <LombardiaTeamsManager teams={teams} />
    </section>
  );
}
