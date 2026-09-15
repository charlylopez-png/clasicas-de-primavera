import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getMundialEvent, isPicksLocked, pointsForPosition } from "@/lib/mundial";
import CountryFlag from "@/components/country-flag";

type SquadRow = {
  user_id: string;
  display_name: string;
  team_name: string | null;
};

type PickRow = {
  user_id: string;
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

  const squadRows = (await sql`
    select s.user_id, u.display_name, s.team_name
    from special_event_squads s
    join users u on u.id = s.user_id
    where s.event_id = ${event.id}
    order by u.display_name
  `) as SquadRow[];

  const pickRows = (await sql`
    select
      p.user_id,
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

  const picksByUser = new Map<string, PickRow[]>();
  for (const row of pickRows) {
    if (!picksByUser.has(row.user_id)) picksByUser.set(row.user_id, []);
    picksByUser.get(row.user_id)!.push(row);
  }

  const standings = squadRows
    .map((s) => {
      const picks = picksByUser.get(s.user_id) ?? [];
      const total = picks.reduce(
        (sum, p) => sum + pointsForPosition(p.position) * Number(p.multiplier),
        0
      );
      return {
        userId: s.user_id,
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
          const revealed = locked || s.userId === session.userId;
          return (
            <div
              key={s.userId}
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
