import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { MUNDIAL_SLUG, pointsForPosition } from "@/lib/mundial";

type PickRow = {
  user_id: string;
  display_name: string;
  rider_name: string;
  team: string | null;
  category: string;
  multiplier: string;
  position: number | null;
};

export default async function MundialClasificacionPage() {
  const session = await getSession();
  if (!session) return null; // el proxy ya redirige a /login antes de llegar aquí

  const events = await sql`select id from special_events where slug = ${MUNDIAL_SLUG}`;
  const eventId = events[0]?.id;

  const rows = eventId
    ? ((await sql`
        select
          u.id as user_id,
          u.display_name,
          r.name as rider_name,
          r.team,
          r.category,
          r.multiplier,
          res.position
        from special_event_picks p
        join users u on u.id = p.user_id
        join special_event_riders r on r.id = p.rider_id
        left join special_event_results res
          on res.event_id = p.event_id and res.rider_id = p.rider_id
        where p.event_id = ${eventId}
        order by u.display_name, r.category
      `) as PickRow[])
    : [];

  const byUser = new Map<
    string,
    {
      displayName: string;
      total: number;
      picks: { name: string; team: string | null; points: number }[];
    }
  >();

  for (const row of rows) {
    if (!byUser.has(row.user_id)) {
      byUser.set(row.user_id, {
        displayName: row.display_name,
        total: 0,
        picks: [],
      });
    }
    const entry = byUser.get(row.user_id)!;
    const points = pointsForPosition(row.position) * Number(row.multiplier);
    entry.total += points;
    entry.picks.push({ name: row.rider_name, team: row.team, points });
  }

  const standings = Array.from(byUser.values()).sort((a, b) => b.total - a.total);

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Mundial de Montreal
      </div>
      <h1 className="text-2xl text-verde-deep">Clasificación</h1>
      <p className="mt-2 text-sm text-text-soft">
        Independiente de la clasificación general de las clásicas.
      </p>

      <div className="mt-6 flex flex-col gap-3">
        {standings.map((s, i) => (
          <div
            key={s.displayName}
            className="rounded-2xl border border-line bg-surface p-4"
          >
            <div className="flex items-center justify-between gap-3">
              <span className="font-display text-sm text-verde-deep">
                {i + 1}. {s.displayName}
              </span>
              <span className="font-display text-lg text-amarillo">
                {s.total.toFixed(1)}
              </span>
            </div>
            <div className="mt-2 flex flex-wrap gap-1.5 text-xs text-text-soft">
              {s.picks.map((p, j) => (
                <span key={j} className="rounded-full border border-line px-2.5 py-1">
                  {p.name} · {p.points.toFixed(1)}
                </span>
              ))}
            </div>
          </div>
        ))}
        {standings.length === 0 && (
          <p className="text-sm text-text-soft">
            Todavía no hay fichajes registrados para esta prueba.
          </p>
        )}
      </div>
    </div>
  );
}
