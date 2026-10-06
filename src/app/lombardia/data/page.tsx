import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import {
  getLombardiaEvent,
  pointsForPosition,
  CATEGORY_LABEL,
  type RiderCategory,
} from "@/lib/lombardia";
import IsoFlag from "@/components/iso-flag";

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-on-accent",
  rojo: "bg-rojo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
};

type RiderResultRow = {
  name: string;
  team: string | null;
  nationality: string | null;
  category: RiderCategory;
  multiplier: string;
  position: number;
};

function formatMultiplier(multiplier: string) {
  return `x${Number(multiplier).toString().replace(".", ",")}`;
}

export default async function LombardiaDataPage() {
  const session = await getSession();
  if (!session) return null; // el proxy ya redirige a /login antes de llegar aquí

  const event = await getLombardiaEvent();
  if (!event) {
    return (
      <p className="text-sm text-text-soft">
        Todavía no se ha configurado esta prueba especial.
      </p>
    );
  }

  const rows = (await sql`
    select r.name, r.team, r.nationality, r.category, r.multiplier, res.position
    from special_event_results res
    join special_event_riders r on r.id = res.rider_id
    where res.event_id = ${event.id}
    order by res.position
  `) as RiderResultRow[];

  const riders = rows
    .map((r) => {
      const base = pointsForPosition(r.position);
      const total = base * Number(r.multiplier);
      return { ...r, base, total };
    })
    .sort((a, b) => b.total - a.total);

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Data</h2>
      <p className="mt-1 max-w-prose text-sm text-text-soft">
        Puntuación individual de cada corredor que puntuó en Il Lombardia:
        puesto en la carrera × coeficiente de categoría. Ordenado de más a
        menos puntos — el orden no siempre coincide con el de la carrera,
        porque el coeficiente también cuenta.
      </p>

      <div className="mt-4 flex flex-col gap-2">
        {riders.map((r, i) => (
          <div
            key={r.name}
            className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-line bg-surface p-3"
          >
            <div className="flex min-w-0 items-center gap-2">
              <span className="shrink-0 font-display text-sm text-text-soft">
                {i + 1}.
              </span>
              <IsoFlag iso={r.nationality} />
              <span className="truncate text-base">{r.name}</span>
            </div>
            <div className="flex w-full flex-wrap items-center justify-end gap-2 sm:w-auto sm:shrink-0">
              <span className="shrink-0 text-xs text-text-soft">
                {r.position}º · {r.base} pts base
              </span>
              <span
                className={`shrink-0 rounded-full px-2.5 py-1 font-display text-xs uppercase tracking-wide ${CATEGORY_STYLES[r.category]}`}
              >
                {CATEGORY_LABEL[r.category]} · {formatMultiplier(r.multiplier)}
              </span>
              <span className="shrink-0 font-display text-base text-amarillo">
                {Number(r.total.toFixed(2))} pts
              </span>
            </div>
          </div>
        ))}
        {riders.length === 0 && (
          <p className="text-sm text-text-soft">
            Todavía no hay resultados cargados para esta prueba.
          </p>
        )}
      </div>
    </section>
  );
}
