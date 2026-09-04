#!/usr/bin/env bash
set -e

if [ ! -f db/schema.sql ]; then
  echo "ERROR: no encuentro db/schema.sql en esta carpeta."
  echo "Asegurate de estar en la raiz del repo clasicas-de-primavera antes de ejecutar este script."
  exit 1
fi

mkdir -p src/lib src/app/calendario "src/app/calendario/[order]"

cat > "src/lib/riders.ts" << 'EOF'
export type RiderCategory = "amarillo" | "rosa" | "verde";

// Debe coincidir siempre con las CategoryCard de /reglamento.
export const CATEGORY_MULTIPLIER: Record<RiderCategory, number> = {
  amarillo: 1,
  rosa: 1.5,
  verde: 2,
};

export const CATEGORY_LABEL: Record<RiderCategory, string> = {
  amarillo: "Amarillo",
  rosa: "Rosa",
  verde: "Verde",
};

// Composición fija de cualquier bloque de 6 (Equipo Base o Last Draft de
// una carrera): 1 Amarillo + 2 Rosas + 3 Verdes.
export const SQUAD_REQUIREMENTS: Record<RiderCategory, number> = {
  amarillo: 1,
  rosa: 2,
  verde: 3,
};
export const SQUAD_SIZE = 6;

export function squadCounts(categories: RiderCategory[]) {
  const counts: Record<RiderCategory, number> = { amarillo: 0, rosa: 0, verde: 0 };
  for (const c of categories) counts[c]++;
  return counts;
}

const MONTHS_ES_LONG = [
  "enero", "febrero", "marzo", "abril", "mayo", "junio",
  "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
];
const MONTHS_ES_SHORT = [
  "ene", "feb", "mar", "abr", "may", "jun",
  "jul", "ago", "sep", "oct", "nov", "dic",
];

// Formatea una fecha de carrera sin desplazamientos de zona horaria. La
// columna `race_date` es un `date` de Postgres: según la versión del
// driver puede llegar como string "YYYY-MM-DD" o ya como objeto Date (en
// cuyo caso usamos los getters UTC, porque un `date` sin hora se
// interpreta en UTC y los getters locales podrían restar/sumar un día
// según la zona horaria del servidor).
export function formatRaceDate(
  value: string | Date,
  style: "long" | "short" = "long"
) {
  let year: number;
  let month: number; // 1-12
  let day: number;
  if (value instanceof Date) {
    year = value.getUTCFullYear();
    month = value.getUTCMonth() + 1;
    day = value.getUTCDate();
  } else {
    [year, month, day] = value.split("-").map(Number);
  }
  if (style === "short") return `${day} ${MONTHS_ES_SHORT[month - 1]} ${year}`;
  return `${day} de ${MONTHS_ES_LONG[month - 1]} de ${year}`;
}

// Los valores numeric de Postgres llegan como string; formatea "1.5" como
// se ve en toda la app: "×1,5".
export function formatCoefficient(value: string | number) {
  const num = typeof value === "string" ? Number(value) : value;
  const text = Number.isInteger(num) ? String(num) : String(num).replace(".", ",");
  return `×${text}`;
}

export function isValidSquad(categories: RiderCategory[]) {
  if (categories.length !== SQUAD_SIZE) return false;
  const counts = squadCounts(categories);
  return (
    counts.amarillo === SQUAD_REQUIREMENTS.amarillo &&
    counts.rosa === SQUAD_REQUIREMENTS.rosa &&
    counts.verde === SQUAD_REQUIREMENTS.verde
  );
}
EOF

cat > "src/app/calendario/page.tsx" << 'EOF'
import Image from "next/image";
import Link from "next/link";
import { sql } from "@/lib/db";
import { formatCoefficient, formatRaceDate } from "@/lib/riders";

type Race = {
  order_num: number;
  name: string;
  stars: number;
  multiplier: string | number;
  logo_path: string;
  race_date: string | Date | null;
};

// La única carrera con fondo oscuro fijo en el logo (Paris–Roubaix).
const DARK_TILE_ORDERS = new Set([9]);

export default async function CalendarioPage() {
  const races = (await sql`
    select order_num, name, stars, multiplier, logo_path, race_date
    from races
    order by order_num
  `) as Race[];

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Calendario 2027
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
              {race.race_date && (
                <div className="text-[11px] text-text-soft">
                  {formatRaceDate(race.race_date, "short")}
                </div>
              )}
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
EOF

cat > "src/app/calendario/[order]/page.tsx" << 'EOF'
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { formatCoefficient, formatRaceDate } from "@/lib/riders";
import SquadSelector, { type SelectableRider } from "@/components/squad-selector";

type Race = {
  id: string;
  order_num: number;
  name: string;
  stars: number;
  multiplier: string | number;
  logo_path: string;
  race_date: string | Date | null;
  official_url: string | null;
};

type HistoryRow = {
  position: number;
  rider_name: string;
  team: string | null;
};

const DARK_TILE_ORDERS = new Set([9]);
const HISTORY_YEAR = 2026;

export default async function RaceDetailPage({
  params,
}: {
  params: Promise<{ order: string }>;
}) {
  const { order } = await params;
  const orderNum = Number(order);
  if (!Number.isInteger(orderNum)) notFound();

  const races = (await sql`
    select id, order_num, name, stars, multiplier, logo_path, race_date, official_url
    from races
    where order_num = ${orderNum}
  `) as Race[];
  const race = races[0];
  if (!race) notFound();

  const history = (await sql`
    select position, rider_name, team
    from race_results_history
    where race_id = ${race.id} and edition_year = ${HISTORY_YEAR}
    order by position
  `) as HistoryRow[];

  const session = await getSession();
  const canDraft = Boolean(session && (session.role === "admin" || session.status === "approved"));

  let riders: SelectableRider[] = [];
  let initialSelectedIds: string[] = [];
  if (canDraft && session) {
    riders = (await sql`
      select id, name, team, division, category
      from riders
      order by division, team, name
    `) as SelectableRider[];
    const picks = (await sql`
      select rider_id from team_last_draft
      where user_id = ${session.userId} and race_id = ${race.id}
    `) as { rider_id: string }[];
    initialSelectedIds = picks.map((p) => p.rider_id);
  }

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <Link href="/calendario" className="text-xs text-text-soft hover:text-verde-deep">
        ← Calendario
      </Link>

      <div className="mt-3 flex items-center gap-4">
        <div
          className={`h-20 w-20 shrink-0 overflow-hidden rounded-2xl border-2 border-white ${
            DARK_TILE_ORDERS.has(race.order_num) ? "bg-[var(--hero-bg-1)]" : "bg-white"
          }`}
        >
          <Image
            src={race.logo_path}
            alt={race.name}
            width={80}
            height={80}
            className="h-full w-full object-cover"
          />
        </div>
        <div className="min-w-0">
          <div className="font-display text-[11px] text-text-soft">
            Carrera {String(race.order_num).padStart(2, "0")} de 12
          </div>
          <h1 className="text-2xl text-verde-deep">{race.name}</h1>
          <div className="mt-1 flex items-center gap-3">
            <span className="text-amarillo" aria-label={`${race.stars} estrellas`}>
              {"★".repeat(race.stars)}
              <span className="text-line">{"★".repeat(5 - race.stars)}</span>
            </span>
            <span className="rounded-full bg-rosa px-2.5 py-1 font-display text-[11px] font-semibold text-white">
              {formatCoefficient(race.multiplier)}
            </span>
          </div>
        </div>
      </div>

      <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-text-soft">
        <span>{race.race_date ? formatRaceDate(race.race_date) : "Fecha por confirmar."}</span>
        {race.official_url && (
          <a
            href={race.official_url}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-verde-deep underline underline-offset-2"
          >
            Web oficial ↗
          </a>
        )}
      </div>

      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        <div className="rounded-2xl border border-dashed border-line bg-surface p-4">
          <h2 className="font-display text-xs uppercase tracking-wide text-verde-deep">
            Perfil de la carrera
          </h2>
          <p className="mt-1.5 text-[13px] leading-relaxed text-text-soft">
            Pendiente de añadir (recorrido, desnivel, tipo de llegada…).
          </p>
        </div>
        <div className="rounded-2xl border border-dashed border-line bg-surface p-4">
          <h2 className="font-display text-xs uppercase tracking-wide text-verde-deep">
            Participantes
          </h2>
          <p className="mt-1.5 text-[13px] leading-relaxed text-text-soft">
            Pendiente de añadir el pelotón inscrito en esta carrera.
          </p>
        </div>
      </div>

      {history.length > 0 && (
        <section className="mt-8">
          <h2 className="font-display text-sm text-verde-deep">
            Edición {HISTORY_YEAR}
          </h2>
          <p className="mt-1 text-sm text-text-soft">
            {history[0] && (
              <>
                Ganador: <b className="text-verde-deep">{history[0].rider_name}</b>
                {history[0].team ? ` (${history[0].team})` : ""}.
              </>
            )}
          </p>
          <div className="mt-3 overflow-hidden rounded-2xl border border-line bg-surface">
            <ol className="divide-y divide-line">
              {history.map((row) => (
                <li
                  key={row.position}
                  className={`flex items-center gap-3 px-4 py-2 text-sm ${
                    row.position === 1 ? "bg-amarillo/20" : ""
                  }`}
                >
                  <span
                    className={`w-6 shrink-0 text-right font-display text-xs ${
                      row.position === 1 ? "text-amarillo" : "text-text-soft"
                    }`}
                  >
                    {row.position}
                  </span>
                  <span className="min-w-0 flex-1 truncate">
                    {row.rider_name}
                    {row.position === 1 && " 🏆"}
                  </span>
                  {row.team && (
                    <span className="shrink-0 truncate text-xs text-text-soft">
                      {row.team}
                    </span>
                  )}
                </li>
              ))}
            </ol>
          </div>
          {history.length < 20 && (
            <p className="mt-2 text-[11px] text-text-soft">
              De momento solo hay {history.length} posiciones confirmadas de esta
              edición.
            </p>
          )}
        </section>
      )}

      <section className="mt-10 pb-6">
        <h2 className="font-display text-sm text-verde-deep">
          Tu fichaje para esta carrera
        </h2>
        <p className="mt-1 text-sm text-text-soft">
          Last Draft: 1 Amarillo, 2 Rosas y 3 Verdes, solo para esta carrera.
        </p>

        {canDraft ? (
          <div className="mt-4 rounded-2xl bg-surface p-4">
            <SquadSelector
              riders={riders}
              initialSelectedIds={initialSelectedIds}
              saveUrl={`/api/races/${race.id}/draft`}
            />
          </div>
        ) : (
          <div className="mt-4 rounded-2xl border border-dashed border-line bg-surface p-6 text-center text-sm text-text-soft">
            {session ? (
              "Tu cuenta todavía no está aprobada."
            ) : (
              <>
                <Link href="/login" className="text-verde-deep underline">
                  Inicia sesión
                </Link>{" "}
                para fichar tu equipo de esta carrera.
              </>
            )}
          </div>
        )}
      </section>
    </div>
  );
}
EOF

git add -A
git commit -m "Arregla el error 500 en /calendario (fecha como Date, no string)

El driver de Neon devuelve race_date (tipo date de Postgres) como
objeto Date en produccion, no como string 'YYYY-MM-DD' como en las
pruebas locales. formatRaceDate hacia .split() sobre ella y rompia
/calendario con TypeError: a.split is not a function. Ahora acepta
ambos formatos.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016LatMv4fA2uvbQTCSnJG6u"
git push
