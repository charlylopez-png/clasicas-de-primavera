#!/usr/bin/env bash
set -euo pipefail

# apply-mundial-data-v13.sh — añade una pestaña "Data" en /mundial,
# visible para todos los jugadores (no solo el admin), con la puntuación
# individual de cada corredor que puntuó en el Mundial: puesto en la
# carrera, categoría/coeficiente y puntos finales (puntos por puesto x
# coeficiente), ordenado de más a menos puntos.
#
# No hace falta ninguna migración SQL para esto.
#
# Ejecuta esto DESDE LA RAÍZ del repo (donde está db/schema.sql), con el
# Codespace ya abierto.

if [ ! -f "db/schema.sql" ]; then
  echo "Error: no se encuentra db/schema.sql en el directorio actual."
  echo "Ejecuta este script desde la raíz del repo clasicas-de-primavera."
  exit 1
fi

echo "Aplicando pestaña Data del Mundial (v13)..."

echo "  - src/app/mundial/data/page.tsx"
mkdir -p "src/app/mundial/data"
cat > "src/app/mundial/data/page.tsx" <<'UKT_MUNDIAL_DATA_V13_EOF'
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import {
  getMundialEvent,
  pointsForPosition,
  CATEGORY_LABEL,
  type RiderCategory,
} from "@/lib/mundial";
import CountryFlag from "@/components/country-flag";

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
};

type RiderResultRow = {
  name: string;
  team: string | null;
  category: RiderCategory;
  multiplier: string;
  position: number;
};

function formatMultiplier(multiplier: string) {
  return `x${Number(multiplier).toString().replace(".", ",")}`;
}

export default async function MundialDataPage() {
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

  const rows = (await sql`
    select r.name, r.team, r.category, r.multiplier, res.position
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
        Puntuación individual de cada corredor que puntuó en el Mundial:
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
              <CountryFlag team={r.team} />
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
                {r.total.toFixed(1)} pts
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
UKT_MUNDIAL_DATA_V13_EOF

echo "  - src/components/mundial-subnav.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-subnav.tsx" <<'UKT_MUNDIAL_DATA_V13_EOF'
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const ITEMS = [
  { href: "/mundial/eleccion", label: "Elección de equipo" },
  { href: "/mundial/equipo", label: "Mi equipo" },
  { href: "/mundial/clasificacion", label: "Clasificación" },
  { href: "/mundial/data", label: "Data" },
  { href: "/mundial/perfil", label: "Perfil y mapa" },
];

const ADMIN_ITEMS = [
  { href: "/mundial/corredores", label: "Corredores" },
  { href: "/mundial/equipos", label: "Equipos" },
  { href: "/mundial/resultados", label: "Resultados" },
];

export default function MundialSubNav({ isAdmin }: { isAdmin: boolean }) {
  const pathname = usePathname();
  const items = isAdmin ? [...ITEMS, ...ADMIN_ITEMS] : ITEMS;

  return (
    <nav className="flex flex-wrap gap-1.5">
      {items.map((item) => {
        const active = pathname === item.href;
        return (
          <Link
            key={item.href}
            href={item.href}
            className={`rounded-full px-3.5 py-2 font-display text-xs uppercase tracking-wide transition ${
              active
                ? "bg-verde-deep text-on-accent"
                : "border border-line bg-surface text-text-soft hover:border-verde-deep/50"
            }`}
          >
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
UKT_MUNDIAL_DATA_V13_EOF


echo ""
echo "Archivos escritos. Creando commit..."
git add -A
git commit -m "Añade pestaña Data en el Mundial con puntos por corredor

Nueva pestaña \"Data\" en /mundial, visible para todos: lista cada
corredor que puntuó en el Mundial con su puesto, categoría/coeficiente y
puntos finales, ordenados de más a menos puntos."
git push

echo ""
echo "Archivos aplicados. No hace falta ninguna migración SQL esta vez."