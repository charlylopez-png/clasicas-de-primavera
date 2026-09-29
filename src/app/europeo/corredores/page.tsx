import { redirect } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import EuropeoRidersManager, {
  type EuropeoAdminRider,
} from "@/components/europeo-riders-manager";
import { EUROPEO_SLUG } from "@/lib/europeo";

export default async function EuropeoCorredoresPage() {
  const session = await getSession();
  if (!session) redirect("/login");
  if (session.role !== "admin") redirect("/europeo");

  const events = await sql`select id from special_events where slug = ${EUROPEO_SLUG}`;
  const eventId = events[0]?.id;

  const riders = eventId
    ? ((await sql`
        select id, name, team, category, multiplier
        from special_event_riders
        where event_id = ${eventId}
        order by name
      `) as EuropeoAdminRider[])
    : [];

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Lista cerrada de corredores</h2>
      <p className="mt-1 max-w-prose text-sm text-text-soft">
        Añade aquí a los corredores convocados para el Europeo y clasifícalos
        en Amarillo, Rosa o Verde. Por defecto entran en Verde. Esta lista es
        propia del Europeo: no toca la base de datos de las clásicas ni la
        del Mundial.
      </p>

      <EuropeoRidersManager initialRiders={riders} />
    </section>
  );
}
