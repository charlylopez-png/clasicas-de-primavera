import { redirect } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import MundialResultsForm, {
  type ResultsRider,
} from "@/components/mundial-results-form";
import { MUNDIAL_SLUG } from "@/lib/mundial";

export default async function MundialResultadosPage() {
  const session = await getSession();
  if (!session) redirect("/login");
  if (session.role !== "admin") redirect("/mundial");

  const events = await sql`select id from special_events where slug = ${MUNDIAL_SLUG}`;
  const eventId = events[0]?.id;

  const riders = eventId
    ? ((await sql`
        select r.id, r.name, r.team, res.position
        from special_event_riders r
        left join special_event_results res
          on res.event_id = r.event_id and res.rider_id = r.id
        where r.event_id = ${eventId}
        order by r.name
      `) as ResultsRider[])
    : [];

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Mundial de Montreal
      </div>
      <h1 className="text-2xl text-verde-deep">Resultados</h1>
      <p className="mt-2 max-w-prose text-sm text-text-soft">
        Introduce el puesto final (1-20) de cada corredor de la lista cerrada.
        Deja el campo vacío si no acabó entre los 20 primeros.
      </p>

      <MundialResultsForm initialRiders={riders} />
    </div>
  );
}
