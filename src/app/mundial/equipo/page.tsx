import Link from "next/link";
import { getSession } from "@/lib/auth";
import { sql } from "@/lib/db";
import {
  CATEGORY_LABEL,
  getMundialEvent,
  isPicksLocked,
  pointsForPosition,
  type RiderCategory,
} from "@/lib/mundial";

type PickRow = {
  name: string;
  team: string | null;
  category: RiderCategory;
  multiplier: string;
  position: number | null;
};

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
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

  const squads = await sql`
    select team_name from special_event_squads
    where event_id = ${event.id} and user_id = ${session.userId}
  `;
  const teamName = squads[0]?.team_name as string | undefined;

  const picks = (await sql`
    select r.name, r.team, r.category, r.multiplier, res.position
    from special_event_picks p
    join special_event_riders r on r.id = p.rider_id
    left join special_event_results res
      on res.event_id = p.event_id and res.rider_id = p.rider_id
    where p.event_id = ${event.id} and p.user_id = ${session.userId}
    order by r.category, r.name
  `) as PickRow[];

  const total = picks.reduce(
    (sum, p) => sum + pointsForPosition(p.position) * Number(p.multiplier),
    0
  );

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Mi equipo</h2>

      {picks.length === 0 ? (
        <div className="mt-4 rounded-2xl border border-dashed border-line bg-surface p-6 text-center text-sm text-text-soft">
          Todavía no has fichado a nadie.{" "}
          <Link href="/mundial/eleccion" className="text-verde-deep underline">
            Elige tu equipo
          </Link>
          .
        </div>
      ) : (
        <div className="mt-4 rounded-2xl bg-surface p-4">
          <div className="flex items-center justify-between gap-3">
            <span className="font-display text-base text-verde-deep">
              {teamName || "(sin nombre)"}
            </span>
            <span className="font-display text-lg text-amarillo">
              {total.toFixed(1)} pts
            </span>
          </div>
          <p className="mt-1 text-xs text-text-soft">{session.displayName}</p>

          <div className="mt-4 flex flex-col gap-1.5">
            {picks.map((p, i) => (
              <div
                key={i}
                className="flex items-center justify-between gap-3 rounded-xl border border-line bg-[var(--bg)] px-3.5 py-2.5"
              >
                <span className="min-w-0 flex-1 truncate">
                  <span className="truncate text-base">{p.name}</span>
                  {p.team && <span className="ml-2 text-xs text-text-soft">{p.team}</span>}
                </span>
                <span
                  className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-display uppercase tracking-wide ${CATEGORY_STYLES[p.category]}`}
                >
                  {CATEGORY_LABEL[p.category]}
                </span>
              </div>
            ))}
          </div>

          {!locked && (
            <Link
              href="/mundial/eleccion"
              className="mt-4 inline-block text-xs text-verde-deep underline underline-offset-2"
            >
              Cambiar equipo
            </Link>
          )}
        </div>
      )}
    </section>
  );
}
