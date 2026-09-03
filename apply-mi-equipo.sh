#!/usr/bin/env bash
set -e

if [ ! -f db/schema.sql ]; then
  echo "ERROR: no encuentro db/schema.sql en esta carpeta."
  echo "Asegurate de estar en la raiz del repo clasicas-de-primavera antes de ejecutar este script."
  exit 1
fi

mkdir -p src/lib src/components src/app/mi-equipo src/app/calendario "src/app/calendario/[order]" "src/app/api/team-base" "src/app/api/races/[id]/draft"

cat > "src/lib/db.ts" << 'EOF'
import { neon, type NeonQueryFunction } from "@neondatabase/serverless";

// Vercel's Neon/Postgres integration injects one of these env var names
// depending on how it was added. We accept any of them so setup is forgiving.
function getConnectionString() {
  return (
    process.env.DATABASE_URL ||
    process.env.POSTGRES_URL ||
    process.env.DATABASE_URL_UNPOOLED ||
    process.env.POSTGRES_URL_NON_POOLING
  );
}

let client: NeonQueryFunction<false, false> | null = null;

// Lazy singleton: we must NOT call neon() at module-evaluation time, because
// Next.js evaluates route modules while collecting build metadata — before
// any env vars from a not-yet-connected database are available. Building
// the client on first real query keeps the build green either way and
// gives a clear runtime error if DATABASE_URL is still missing.
function getClient(): NeonQueryFunction<false, false> {
  if (client) return client;
  const connectionString = getConnectionString();
  if (!connectionString) {
    throw new Error(
      "Falta DATABASE_URL (o POSTGRES_URL). Añade la base de datos en Vercel → Storage y conéctala a este proyecto, o defínela en .env.local para desarrollo."
    );
  }
  client = neon(connectionString);
  return client;
}

// Tagged-template proxy so call sites keep writing `sql`...``` unchanged.
export const sql: NeonQueryFunction<false, false> = ((
  strings: TemplateStringsArray,
  ...values: unknown[]
) => getClient()(strings, ...values)) as NeonQueryFunction<false, false>;

export function hasDatabase() {
  return Boolean(getConnectionString());
}

// Para operaciones que deben ser todo-o-nada (p.ej. sustituir las 6 fichas
// de un equipo): junta varias queries construidas con `sql` en una única
// transacción HTTP no interactiva. No las awaitees antes de pasarlas aquí.
export function transaction<T = unknown>(
  queries: Promise<T>[]
): Promise<T[]> {
  return getClient().transaction(queries as never) as Promise<T[]>;
}
EOF

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

cat > "src/components/squad-selector.tsx" << 'EOF'
"use client";

import { useMemo, useState, useTransition } from "react";
import {
  CATEGORY_LABEL,
  SQUAD_REQUIREMENTS,
  SQUAD_SIZE,
  squadCounts,
  type RiderCategory,
} from "@/lib/riders";

export type SelectableRider = {
  id: string;
  name: string;
  team: string | null;
  division: "worldtour" | "proteam" | null;
  category: RiderCategory;
};

const CATEGORIES: RiderCategory[] = ["amarillo", "rosa", "verde"];

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-[#372802]",
  rosa: "bg-rosa text-white",
  verde: "bg-verde text-[var(--hero-text)]",
};

export default function SquadSelector({
  riders,
  initialSelectedIds,
  saveUrl,
}: {
  riders: SelectableRider[];
  initialSelectedIds: string[];
  saveUrl: string;
}) {
  const [selected, setSelected] = useState<Set<string>>(
    () => new Set(initialSelectedIds)
  );
  const [query, setQuery] = useState("");
  const [division, setDivision] = useState<"all" | "worldtour" | "proteam">("all");
  const [isPending, startTransition] = useTransition();
  const [feedback, setFeedback] = useState<
    { type: "ok" | "error"; text: string } | null
  >(null);

  const ridersById = useMemo(() => {
    const m = new Map<string, SelectableRider>();
    for (const r of riders) m.set(r.id, r);
    return m;
  }, [riders]);

  const counts = useMemo(() => {
    const cats = Array.from(selected)
      .map((id) => ridersById.get(id)?.category)
      .filter((c): c is RiderCategory => Boolean(c));
    return squadCounts(cats);
  }, [selected, ridersById]);

  const total = selected.size;
  const canSave =
    total === SQUAD_SIZE &&
    counts.amarillo === SQUAD_REQUIREMENTS.amarillo &&
    counts.rosa === SQUAD_REQUIREMENTS.rosa &&
    counts.verde === SQUAD_REQUIREMENTS.verde;

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return riders.filter((r) => {
      if (division !== "all" && r.division !== division) return false;
      if (!q) return true;
      return (
        r.name.toLowerCase().includes(q) || (r.team ?? "").toLowerCase().includes(q)
      );
    });
  }, [riders, query, division]);

  const groups = useMemo(() => {
    const byTeam = new Map<string, SelectableRider[]>();
    for (const r of filtered) {
      const key = r.team ?? "Sin equipo";
      if (!byTeam.has(key)) byTeam.set(key, []);
      byTeam.get(key)!.push(r);
    }
    return Array.from(byTeam.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [filtered]);

  function toggle(rider: SelectableRider) {
    setFeedback(null);
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(rider.id)) {
        next.delete(rider.id);
        return next;
      }
      const currentCount = squadCounts(
        Array.from(prev)
          .map((id) => ridersById.get(id)?.category)
          .filter((c): c is RiderCategory => Boolean(c))
      )[rider.category];
      if (currentCount >= SQUAD_REQUIREMENTS[rider.category]) {
        return prev; // ya está completo ese hueco, no hace nada
      }
      next.add(rider.id);
      return next;
    });
  }

  function save() {
    setFeedback(null);
    startTransition(async () => {
      const res = await fetch(saveUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ riderIds: Array.from(selected) }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setFeedback({ type: "error", text: data?.error ?? "No se pudo guardar." });
        return;
      }
      setFeedback({ type: "ok", text: "Guardado." });
    });
  }

  return (
    <div>
      <div className="flex flex-wrap items-center gap-2">
        {CATEGORIES.map((c) => (
          <span
            key={c}
            className={`rounded-full px-2.5 py-1 font-display text-[11px] uppercase tracking-wide ${
              counts[c] === SQUAD_REQUIREMENTS[c]
                ? CATEGORY_STYLES[c]
                : "border border-line bg-transparent text-text-soft"
            }`}
          >
            {CATEGORY_LABEL[c]} · {counts[c]}/{SQUAD_REQUIREMENTS[c]}
          </span>
        ))}
        <button
          type="button"
          disabled={!canSave || isPending}
          onClick={save}
          className="ml-auto rounded-full bg-verde-deep px-4 py-2 font-display text-xs uppercase tracking-wide text-white disabled:opacity-40"
        >
          {isPending ? "Guardando…" : `Guardar (${total}/${SQUAD_SIZE})`}
        </button>
      </div>
      {feedback && (
        <p
          className={`mt-2 text-xs ${
            feedback.type === "ok" ? "text-verde-deep" : "text-rosa"
          }`}
        >
          {feedback.text}
        </p>
      )}

      <div className="mt-4 flex flex-col gap-2 sm:flex-row">
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Buscar corredor o equipo…"
          className="w-full rounded-full border border-line bg-surface px-4 py-2 text-sm outline-none focus:border-verde"
        />
        <select
          value={division}
          onChange={(e) => setDivision(e.target.value as typeof division)}
          className="rounded-full border border-line bg-surface px-4 py-2 text-sm outline-none focus:border-verde"
        >
          <option value="all">Todas las divisiones</option>
          <option value="worldtour">World Tour</option>
          <option value="proteam">ProTeam</option>
        </select>
      </div>

      <div className="mt-5 flex flex-col gap-6">
        {groups.map(([team, teamRiders]) => (
          <div key={team}>
            <h3 className="font-display text-xs uppercase tracking-wide text-verde-deep">
              {team}
            </h3>
            <div className="mt-2 flex flex-col gap-1.5">
              {teamRiders.map((rider) => {
                const isSelected = selected.has(rider.id);
                const full =
                  !isSelected && counts[rider.category] >= SQUAD_REQUIREMENTS[rider.category];
                return (
                  <button
                    key={rider.id}
                    type="button"
                    disabled={full}
                    onClick={() => toggle(rider)}
                    className={`flex items-center justify-between gap-3 rounded-xl border px-3 py-2 text-left transition ${
                      isSelected
                        ? "border-verde-deep bg-verde-deep/10"
                        : full
                        ? "border-line bg-surface opacity-40"
                        : "border-line bg-surface hover:border-verde-deep/50"
                    }`}
                  >
                    <span className="min-w-0 truncate text-sm">{rider.name}</span>
                    <span
                      className={`shrink-0 rounded-full px-2 py-0.5 text-[10px] font-display uppercase tracking-wide ${CATEGORY_STYLES[rider.category]}`}
                    >
                      {CATEGORY_LABEL[rider.category]}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        ))}
        {groups.length === 0 && (
          <p className="text-sm text-text-soft">No hay corredores que coincidan.</p>
        )}
      </div>
    </div>
  );
}
EOF

cat > "src/app/api/team-base/route.ts" << 'EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql, transaction } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { isValidSquad, SQUAD_SIZE, type RiderCategory } from "@/lib/riders";

const BodySchema = z.object({
  riderIds: z.array(z.string().uuid()).length(SQUAD_SIZE),
});

export async function POST(request: Request) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "No autorizado." }, { status: 401 });
  }
  if (session.role !== "admin" && session.status !== "approved") {
    return NextResponse.json({ error: "Tu cuenta todavía no está aprobada." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: `El Equipo Base debe tener exactamente ${SQUAD_SIZE} corredores.` },
      { status: 400 }
    );
  }

  const riderIds = Array.from(new Set(parsed.data.riderIds));
  if (riderIds.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Hay corredores repetidos en la selección." },
      { status: 400 }
    );
  }

  const rows = (await sql`
    select id, category from riders where id = any(${riderIds}::uuid[])
  `) as { id: string; category: RiderCategory }[];

  if (rows.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Alguno de los corredores seleccionados ya no existe." },
      { status: 400 }
    );
  }

  if (!isValidSquad(rows.map((r) => r.category))) {
    return NextResponse.json(
      { error: "El Equipo Base debe ser 1 Amarillo + 2 Rosas + 3 Verdes." },
      { status: 400 }
    );
  }

  await transaction([
    sql`delete from team_base where user_id = ${session.userId}`,
    sql`
      insert into team_base (user_id, rider_id)
      select ${session.userId}::uuid, unnest(${riderIds}::uuid[])
    `,
  ]);

  return NextResponse.json({ ok: true });
}
EOF

cat > "src/app/api/races/[id]/draft/route.ts" << 'EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql, transaction } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { isValidSquad, SQUAD_SIZE, type RiderCategory } from "@/lib/riders";

const BodySchema = z.object({
  riderIds: z.array(z.string().uuid()).length(SQUAD_SIZE),
});

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "No autorizado." }, { status: 401 });
  }
  if (session.role !== "admin" && session.status !== "approved") {
    return NextResponse.json({ error: "Tu cuenta todavía no está aprobada." }, { status: 403 });
  }

  const { id: raceId } = await params;
  const race = await sql`select id from races where id = ${raceId}`;
  if (race.length === 0) {
    return NextResponse.json({ error: "Esa carrera no existe." }, { status: 404 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: `El fichaje debe tener exactamente ${SQUAD_SIZE} corredores.` },
      { status: 400 }
    );
  }

  const riderIds = Array.from(new Set(parsed.data.riderIds));
  if (riderIds.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Hay corredores repetidos en la selección." },
      { status: 400 }
    );
  }

  const rows = (await sql`
    select id, category from riders where id = any(${riderIds}::uuid[])
  `) as { id: string; category: RiderCategory }[];

  if (rows.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Alguno de los corredores seleccionados ya no existe." },
      { status: 400 }
    );
  }

  if (!isValidSquad(rows.map((r) => r.category))) {
    return NextResponse.json(
      { error: "El fichaje debe ser 1 Amarillo + 2 Rosas + 3 Verdes." },
      { status: 400 }
    );
  }

  await transaction([
    sql`delete from team_last_draft where user_id = ${session.userId} and race_id = ${raceId}`,
    sql`
      insert into team_last_draft (user_id, race_id, rider_id)
      select ${session.userId}::uuid, ${raceId}::uuid, unnest(${riderIds}::uuid[])
    `,
  ]);

  return NextResponse.json({ ok: true });
}
EOF

cat > "src/app/mi-equipo/page.tsx" << 'EOF'
import Link from "next/link";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import SquadSelector, { type SelectableRider } from "@/components/squad-selector";
import type { RiderCategory } from "@/lib/riders";

type RaceRow = {
  order_num: number;
  name: string;
};

type DraftPick = {
  order_num: number;
  name: string;
  category: RiderCategory;
};

export default async function MiEquipoPage() {
  const session = await getSession();
  if (!session) return null; // el proxy ya redirige a /login antes de llegar aquí

  const riders = (await sql`
    select id, name, team, division, category
    from riders
    order by division, team, name
  `) as SelectableRider[];

  const teamBase = (await sql`
    select rider_id from team_base where user_id = ${session.userId}
  `) as { rider_id: string }[];

  const races = (await sql`
    select order_num, name from races order by order_num
  `) as RaceRow[];

  const picks = (await sql`
    select r.order_num, ri.name, ri.category
    from team_last_draft tld
    join races r on r.id = tld.race_id
    join riders ri on ri.id = tld.rider_id
    where tld.user_id = ${session.userId}
    order by r.order_num, ri.category
  `) as DraftPick[];

  const picksByRace = new Map<number, DraftPick[]>();
  for (const p of picks) {
    if (!picksByRace.has(p.order_num)) picksByRace.set(p.order_num, []);
    picksByRace.get(p.order_num)!.push(p);
  }

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Tu plantilla
      </div>
      <h1 className="text-2xl text-verde-deep">
        Hola, {session.displayName}
      </h1>

      <section className="mt-8">
        <h2 className="font-display text-sm text-verde-deep">Equipo Base</h2>
        <p className="mt-1 text-sm text-text-soft">
          6 corredores fijos para toda la temporada: 1 Amarillo, 2 Rosas y 3
          Verdes. Si el Sanedrín todavía no ha clasificado a nadie fuera de
          Verde, espera a que lo haga antes de poder completar el equipo.
        </p>
        <div className="mt-4 rounded-2xl bg-surface p-4">
          <SquadSelector
            riders={riders}
            initialSelectedIds={teamBase.map((r) => r.rider_id)}
            saveUrl="/api/team-base"
          />
        </div>
      </section>

      <section className="mt-10 pb-6">
        <h2 className="font-display text-sm text-verde-deep">
          Fichajes por carrera
        </h2>
        <p className="mt-1 text-sm text-text-soft">
          El Last Draft se elige carrera a carrera, desde la página de cada
          una. Aquí solo ves el resumen.
        </p>
        <div className="mt-4 flex flex-col gap-2">
          {races.map((race) => {
            const racePicks = picksByRace.get(race.order_num) ?? [];
            return (
              <Link
                key={race.order_num}
                href={`/calendario/${race.order_num}`}
                className="flex items-center justify-between gap-3 rounded-xl border border-line bg-surface px-4 py-3 hover:border-verde-deep/50"
              >
                <div className="min-w-0">
                  <div className="font-display text-[11px] text-text-soft">
                    {String(race.order_num).padStart(2, "0")}
                  </div>
                  <div className="truncate text-sm font-semibold">{race.name}</div>
                </div>
                {racePicks.length === 6 ? (
                  <span className="shrink-0 rounded-full bg-verde px-2.5 py-1 text-[11px] font-semibold text-[var(--hero-text)]">
                    Fichado ✓
                  </span>
                ) : (
                  <span className="shrink-0 rounded-full border border-line px-2.5 py-1 text-[11px] text-text-soft">
                    Sin fichar
                  </span>
                )}
              </Link>
            );
          })}
        </div>
      </section>
    </div>
  );
}

EOF

cat > "src/app/calendario/page.tsx" << 'EOF'
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
EOF

cat > "src/app/calendario/[order]/page.tsx" << 'EOF'
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { formatCoefficient } from "@/lib/riders";
import SquadSelector, { type SelectableRider } from "@/components/squad-selector";

type Race = {
  id: string;
  order_num: number;
  name: string;
  stars: number;
  multiplier: string | number;
  logo_path: string;
  race_date: string | null;
};

const DARK_TILE_ORDERS = new Set([9]);

export default async function RaceDetailPage({
  params,
}: {
  params: Promise<{ order: string }>;
}) {
  const { order } = await params;
  const orderNum = Number(order);
  if (!Number.isInteger(orderNum)) notFound();

  const races = (await sql`
    select id, order_num, name, stars, multiplier, logo_path, race_date
    from races
    where order_num = ${orderNum}
  `) as Race[];
  const race = races[0];
  if (!race) notFound();

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

      <p className="mt-3 text-sm text-text-soft">
        {race.race_date
          ? new Date(race.race_date).toLocaleDateString("es-ES", {
              day: "numeric",
              month: "long",
              year: "numeric",
            })
          : "Fecha por confirmar."}
      </p>

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
git commit -m "Anade la seleccion de Equipo Base y el Last Draft por carrera

- /mi-equipo: elige el Equipo Base (1 Amarillo + 2 Rosas + 3 Verdes),
  buscando por nombre o navegando la lista agrupada por equipos; guarda
  con /api/team-base
- /mi-equipo tambien resume el estado del fichaje (Last Draft) de cada
  una de las 12 carreras, con enlace a cada una
- /calendario/[numero]: pagina de cada carrera con su cabecera, huecos
  para perfil y participantes (pendientes de contenido) y el selector
  de Last Draft de esa carrera; guarda con /api/races/[id]/draft
- /calendario ahora lee las carreras de la base de datos en vez de una
  lista fija en el codigo, para que este siempre en sincronia con
  /calendario/[numero]

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016LatMv4fA2uvbQTCSnJG6u"
git push
