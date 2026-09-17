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
