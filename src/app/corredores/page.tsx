import { redirect } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import RidersManager, { type Rider } from "@/components/riders-manager";

export default async function CorredoresPage() {
  const session = await getSession();
  if (!session) redirect("/login");

  // No nos fiamos del JWT para el permiso de Sanedrín: se reconsulta
  // siempre en caliente, porque el admin puede cambiarlo en cualquier
  // momento y el token dura 30 días.
  let allowed = session.role === "admin";
  if (!allowed) {
    const rows = await sql`
      select is_sanedrin from users where id = ${session.userId}
    `;
    allowed = Boolean(rows[0]?.is_sanedrin);
  }
  if (!allowed) redirect("/mi-equipo");

  const riders = (await sql`
    select id, name, team, division, category, multiplier
    from riders
    order by division, team, name
  `) as Rider[];

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        El Sanedrín
      </div>
      <h1 className="text-2xl text-verde-deep">Base de datos de corredores</h1>
      <p className="mt-2 max-w-prose text-sm text-text-soft">
        World Tour y ProTeam, temporada 2026 (datos de partida, se
        sustituirán más adelante por la temporada real). Por defecto todos
        están en Verde: reclasifica aquí a los favoritos en Amarillo y a los
        candidatos serios en Rosa.
      </p>

      <RidersManager initialRiders={riders} />
    </div>
  );
}
