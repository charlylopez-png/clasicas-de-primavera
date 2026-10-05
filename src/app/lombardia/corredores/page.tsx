import { redirect } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import LombardiaRidersManager, {
  type LombardiaAdminRider,
} from "@/components/lombardia-riders-manager";
import { LOMBARDIA_SLUG } from "@/lib/lombardia";

export default async function LombardiaCorredoresPage() {
  const session = await getSession();
  if (!session) redirect("/login");
  if (session.role !== "admin") redirect("/lombardia");

  const events = await sql`select id from special_events where slug = ${LOMBARDIA_SLUG}`;
  const eventId = events[0]?.id;

  const riders = eventId
    ? ((await sql`
        select id, name, team, category, multiplier
        from special_event_riders
        where event_id = ${eventId}
        order by name
      `) as LombardiaAdminRider[])
    : [];

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Lista cerrada de corredores</h2>
      <p className="mt-1 max-w-prose text-sm text-text-soft">
        Añade aquí a los corredores convocados para Il Lombardia y clasifícalos
        en Amarillo, Rosa o Verde. Por defecto entran en Verde. Esta lista es
        propia de Il Lombardia: no toca la base de datos de las clásicas ni la
        del Mundial.
      </p>

      <LombardiaRidersManager initialRiders={riders} />
    </section>
  );
}
