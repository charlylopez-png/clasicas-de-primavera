import { redirect } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import MundialRidersManager, {
  type MundialAdminRider,
} from "@/components/mundial-riders-manager";
import { MUNDIAL_SLUG } from "@/lib/mundial";

export default async function MundialCorredoresPage() {
  const session = await getSession();
  if (!session) redirect("/login");
  if (session.role !== "admin") redirect("/mundial");

  const events = await sql`select id from special_events where slug = ${MUNDIAL_SLUG}`;
  const eventId = events[0]?.id;

  const riders = eventId
    ? ((await sql`
        select id, name, team, category, multiplier
        from special_event_riders
        where event_id = ${eventId}
        order by name
      `) as MundialAdminRider[])
    : [];

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Mundial de Montreal
      </div>
      <h1 className="text-2xl text-verde-deep">Lista cerrada de corredores</h1>
      <p className="mt-2 max-w-prose text-sm text-text-soft">
        Añade aquí a los corredores convocados para el Mundial y clasifícalos
        en Amarillo, Rosa o Verde. Por defecto entran en Verde. Esta lista es
        propia del Mundial: no toca la base de datos de las clásicas.
      </p>

      <MundialRidersManager initialRiders={riders} />
    </div>
  );
}
