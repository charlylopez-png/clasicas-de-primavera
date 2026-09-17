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
