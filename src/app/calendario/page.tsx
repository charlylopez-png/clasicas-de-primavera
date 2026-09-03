import Image from "next/image";
import Link from "next/link";
import { sql } from "@/lib/db";
import { formatCoefficient } from "@/lib/riders";

type Race = {
  order_num: number;
  name: string;
  stars: number;
  multiplier: string | number;
  logo_path: string;
};

// La única carrera con fondo oscuro fijo en el logo (Paris–Roubaix).
const DARK_TILE_ORDERS = new Set([9]);

export default async function CalendarioPage() {
  const races = (await sql`
    select order_num, name, stars, multiplier, logo_path
    from races
    order by order_num
  `) as Race[];

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Calendario 2026
      </div>
      <h1 className="text-2xl text-verde-deep">Las 12 clásicas</h1>
      <p className="mt-2 max-w-prose text-sm text-text-soft">
        De finales de febrero a finales de abril, con su categoría y el
        coeficiente que aporta a la puntuación. Pincha en una carrera para
        ver sus datos y fichar tu Last Draft.
      </p>

      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        {races.map((race) => (
          <Link
            key={race.order_num}
            href={`/calendario/${race.order_num}`}
            className="flex items-center gap-4 rounded-2xl border border-line bg-surface p-3 hover:border-verde-deep/50"
          >
            <div
              className={`h-16 w-16 shrink-0 overflow-hidden rounded-xl border-2 border-white ${
                DARK_TILE_ORDERS.has(race.order_num) ? "bg-[var(--hero-bg-1)]" : "bg-white"
              }`}
            >
              <Image
                src={race.logo_path}
                alt={race.name}
                width={64}
                height={64}
                className="h-full w-full object-cover"
              />
            </div>
            <div className="min-w-0 flex-1">
              <div className="font-display text-[11px] text-text-soft">
                {String(race.order_num).padStart(2, "0")}
              </div>
              <div className="truncate text-sm font-semibold">{race.name}</div>
              <div className="mt-0.5 text-amarillo" aria-label={`${race.stars} estrellas`}>
                {"★".repeat(race.stars)}
                <span className="text-line">{"★".repeat(5 - race.stars)}</span>
              </div>
            </div>
            <span className="shrink-0 rounded-full bg-rosa px-2.5 py-1 font-display text-[11px] font-semibold text-white">
              {formatCoefficient(race.multiplier)}
            </span>
          </Link>
        ))}
      </div>

      <div className="mt-6 flex flex-wrap gap-x-4 gap-y-2 text-[11px] text-text-soft">
        <span>★★ = ×1</span>
        <span>★★★ = ×1,5</span>
        <span>★★★★ = ×1,75</span>
        <span>★★★★★ = ×2 (Monumentos)</span>
      </div>

      <div className="mt-4 rounded-lg border-l-[3px] border-verde bg-surface p-3 text-[13px] leading-relaxed text-text-soft">
        Las cinco estrellas son los cuatro Monumentos de la porra:
        Milano–Sanremo, Ronde van Vlaanderen, Paris–Roubaix y
        Liège–Bastogne–Liège.
      </div>
    </div>
  );
}
