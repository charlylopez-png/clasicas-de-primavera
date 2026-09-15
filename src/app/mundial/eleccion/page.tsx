import { getSession } from "@/lib/auth";
import { sql } from "@/lib/db";
import MundialSquadSelector, {
  type MundialRider,
} from "@/components/mundial-squad-selector";
import { getMundialEvent, isPicksLocked } from "@/lib/mundial";

export default async function MundialEleccionPage() {
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

  const riders = (await sql`
    select id, name, team, category
    from special_event_riders
    where event_id = ${event.id}
    order by team, name
  `) as MundialRider[];

  const picks = (await sql`
    select rider_id from special_event_picks
    where event_id = ${event.id} and user_id = ${session.userId}
  `) as { rider_id: string }[];

  const squads = (await sql`
    select team_name from special_event_squads
    where event_id = ${event.id} and user_id = ${session.userId}
  `) as { team_name: string }[];

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Elección de equipo</h2>
      <p className="mt-1 text-sm text-text-soft">
        Ponle un nombre a tu equipo y elige 6 corredores de la lista cerrada: 1
        Amarillo, 2 Rosas y 3 Verdes. Puedes cambiarlo cuantas veces quieras
        hasta la fecha límite.
      </p>

      <div className="mt-4 rounded-2xl bg-surface p-4">
        {riders.length === 0 ? (
          <p className="text-sm text-text-soft">
            Todavía no hay lista de corredores para esta prueba.
          </p>
        ) : (
          <MundialSquadSelector
            riders={riders}
            initialSelectedIds={picks.map((p) => p.rider_id)}
            initialTeamName={squads[0]?.team_name ?? ""}
            locked={locked}
          />
        )}
      </div>
    </section>
  );
}
