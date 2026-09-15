#!/usr/bin/env bash
set -euo pipefail

# apply-mundial-v2.sh — amplía la prueba especial "Mundial de Montreal":
# submenú (Mi equipo / Elección / Clasificación / Perfil y mapa), nombre
# de equipo por jugador (oculto a los demás hasta el cierre), tema visual
# propio, logo arcoíris en el menú superior y banner en la portada.
#
# Ejecuta esto DESDE LA RAÍZ del repo (donde está db/schema.sql), con el
# Codespace ya abierto. Requiere haber aplicado antes apply-mundial.sh.

if [ ! -f "db/schema.sql" ]; then
  echo "Error: no se encuentra db/schema.sql en el directorio actual."
  echo "Ejecuta este script desde la raíz del repo clasicas-de-primavera."
  exit 1
fi

if [ ! -f "src/lib/mundial.ts" ]; then
  echo "Aviso: no encuentro src/lib/mundial.ts — parece que todavía no has"
  echo "aplicado apply-mundial.sh. Este script lo sustituye igualmente,"
  echo "pero asegúrate de haber cargado ya mundial_migration.sql y"
  echo "mundial_riders_seed.sql en Neon antes de continuar."
fi

echo "Aplicando la ampliación del Mundial de Montreal (v2)..."

echo "  - src/lib/mundial.ts"
mkdir -p "src/lib"
cat > "src/lib/mundial.ts" <<'UKT_MUNDIAL_V2_EOF'
import { sql } from "./db";
import type { RiderCategory } from "./riders";
export type { RiderCategory };

// Todo lo de este fichero es deliberadamente independiente de lib/riders.ts:
// el Mundial de Montreal es una prueba única y separada de la porra de
// clásicas (mismo login, misma web, pero ni corredores ni puntuación se
// mezclan con la general).

export const MUNDIAL_SLUG = "montreal-2026";

export type MundialEvent = {
  id: string;
  name: string;
  event_date: string | Date | null;
  picks_lock_at: string | Date | null;
};

// Usado por todas las páginas de /mundial/*: evita repetir la misma
// consulta en cada page.tsx.
export async function getMundialEvent(): Promise<MundialEvent | null> {
  const events = (await sql`
    select id, name, event_date, picks_lock_at
    from special_events where slug = ${MUNDIAL_SLUG}
  `) as MundialEvent[];
  return events[0] ?? null;
}

export function isPicksLocked(picksLockAt: string | Date | null) {
  if (!picksLockAt) return false;
  return new Date(picksLockAt).getTime() <= Date.now();
}

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

// Misma composición que Equipo Base / Last Draft: 1 Amarillo + 2 Rosas + 3
// Verdes = 6 corredores.
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

export function isValidSquad(categories: RiderCategory[]) {
  if (categories.length !== SQUAD_SIZE) return false;
  const counts = squadCounts(categories);
  return (
    counts.amarillo === SQUAD_REQUIREMENTS.amarillo &&
    counts.rosa === SQUAD_REQUIREMENTS.rosa &&
    counts.verde === SQUAD_REQUIREMENTS.verde
  );
}

// Misma tabla de puntos por puesto que las clásicas (1º-20º).
export const POINTS_BY_POSITION: Record<number, number> = {
  1: 100, 2: 50, 3: 30, 4: 20, 5: 16, 6: 15, 7: 14, 8: 13, 9: 12, 10: 11,
  11: 10, 12: 9, 13: 8, 14: 7, 15: 6, 16: 5, 17: 4, 18: 3, 19: 2, 20: 1,
};

export function pointsForPosition(position: number | null | undefined) {
  if (!position) return 0;
  return POINTS_BY_POSITION[position] ?? 0;
}

export function formatEventDate(value: string | Date) {
  let year: number;
  let month: number;
  let day: number;
  if (value instanceof Date) {
    year = value.getUTCFullYear();
    month = value.getUTCMonth() + 1;
    day = value.getUTCDate();
  } else {
    [year, month, day] = value.split("-").map(Number);
  }
  const MONTHS = [
    "enero", "febrero", "marzo", "abril", "mayo", "junio",
    "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
  ];
  return `${day} de ${MONTHS[month - 1]} de ${year}`;
}
UKT_MUNDIAL_V2_EOF

echo "  - src/app/api/mundial/picks/route.ts"
mkdir -p "src/app/api/mundial/picks"
cat > "src/app/api/mundial/picks/route.ts" <<'UKT_MUNDIAL_V2_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql, transaction } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { isValidSquad, SQUAD_SIZE, MUNDIAL_SLUG, type RiderCategory } from "@/lib/mundial";

const BodySchema = z.object({
  riderIds: z.array(z.string().uuid()).length(SQUAD_SIZE),
  teamName: z.string().trim().min(1).max(60),
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
      {
        error: `Ponle un nombre a tu equipo y elige exactamente ${SQUAD_SIZE} corredores.`,
      },
      { status: 400 }
    );
  }

  const events = await sql`
    select id, picks_lock_at from special_events where slug = ${MUNDIAL_SLUG}
  `;
  const event = events[0];
  if (!event) {
    return NextResponse.json({ error: "No se encuentra el evento del Mundial." }, { status: 500 });
  }
  if (event.picks_lock_at && new Date(event.picks_lock_at).getTime() <= Date.now()) {
    return NextResponse.json(
      { error: "Los fichajes para el Mundial ya están cerrados." },
      { status: 403 }
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
    select id, category from special_event_riders
    where event_id = ${event.id} and id = any(${riderIds}::uuid[])
  `) as { id: string; category: RiderCategory }[];

  if (rows.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Alguno de los corredores seleccionados ya no existe." },
      { status: 400 }
    );
  }

  if (!isValidSquad(rows.map((r) => r.category))) {
    return NextResponse.json(
      { error: "El equipo debe ser 1 Amarillo + 2 Rosas + 3 Verdes." },
      { status: 400 }
    );
  }

  await transaction([
    sql`delete from special_event_picks where event_id = ${event.id} and user_id = ${session.userId}`,
    sql`
      insert into special_event_picks (event_id, user_id, rider_id)
      select ${event.id}::uuid, ${session.userId}::uuid, unnest(${riderIds}::uuid[])
    `,
    sql`
      insert into special_event_squads (event_id, user_id, team_name, updated_at)
      values (${event.id}, ${session.userId}, ${parsed.data.teamName}, now())
      on conflict (event_id, user_id) do update
      set team_name = excluded.team_name, updated_at = excluded.updated_at
    `,
  ]);

  return NextResponse.json({ ok: true });
}
UKT_MUNDIAL_V2_EOF

echo "  - src/components/mundial-squad-selector.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-squad-selector.tsx" <<'UKT_MUNDIAL_V2_EOF'
"use client";

import { useMemo, useState, useTransition } from "react";
import {
  CATEGORY_LABEL,
  SQUAD_REQUIREMENTS,
  SQUAD_SIZE,
  squadCounts,
  type RiderCategory,
} from "@/lib/mundial";

export type MundialRider = {
  id: string;
  name: string;
  team: string | null;
  category: RiderCategory;
};

const CATEGORIES: RiderCategory[] = ["amarillo", "rosa", "verde"];

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
};

export default function MundialSquadSelector({
  riders,
  initialSelectedIds,
  initialTeamName,
  locked,
}: {
  riders: MundialRider[];
  initialSelectedIds: string[];
  initialTeamName: string;
  locked: boolean;
}) {
  const [selected, setSelected] = useState<Set<string>>(
    () => new Set(initialSelectedIds)
  );
  const [teamName, setTeamName] = useState(initialTeamName);
  const [query, setQuery] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<"all" | RiderCategory>("all");
  const [isPending, startTransition] = useTransition();
  const [feedback, setFeedback] = useState<
    { type: "ok" | "error"; text: string } | null
  >(null);

  const ridersById = useMemo(() => {
    const m = new Map<string, MundialRider>();
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
    !locked &&
    total === SQUAD_SIZE &&
    teamName.trim().length > 0 &&
    counts.amarillo === SQUAD_REQUIREMENTS.amarillo &&
    counts.rosa === SQUAD_REQUIREMENTS.rosa &&
    counts.verde === SQUAD_REQUIREMENTS.verde;

  // Agrupados por país en primer lugar (no alfabético por nombre): cada
  // grupo es un país, y dentro se puede seguir filtrando por color.
  const groups = useMemo(() => {
    const q = query.trim().toLowerCase();
    const byCountry = new Map<string, MundialRider[]>();
    for (const r of riders) {
      if (categoryFilter !== "all" && r.category !== categoryFilter) continue;
      if (q && !r.name.toLowerCase().includes(q) && !(r.team ?? "").toLowerCase().includes(q)) {
        continue;
      }
      const key = r.team ?? "Sin país";
      if (!byCountry.has(key)) byCountry.set(key, []);
      byCountry.get(key)!.push(r);
    }
    for (const list of byCountry.values()) {
      list.sort((a, b) => a.name.localeCompare(b.name));
    }
    return Array.from(byCountry.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [riders, query, categoryFilter]);

  function toggle(rider: MundialRider) {
    if (locked) return;
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
        return prev;
      }
      next.add(rider.id);
      return next;
    });
  }

  function save() {
    setFeedback(null);
    startTransition(async () => {
      const res = await fetch("/api/mundial/picks", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          riderIds: Array.from(selected),
          teamName: teamName.trim(),
        }),
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
      {locked ? (
        <p className="font-display text-sm uppercase tracking-wide text-verde-deep">
          {teamName || "Sin nombre de equipo"}
        </p>
      ) : (
        <input
          type="text"
          value={teamName}
          onChange={(e) => setTeamName(e.target.value)}
          maxLength={60}
          placeholder="Nombre de tu equipo (ej. Los Rompepiernas)"
          className="w-full rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
        />
      )}

      <div className="mt-3 flex flex-wrap items-center gap-2">
        {CATEGORIES.map((c) => (
          <span
            key={c}
            className={`rounded-full px-3 py-1.5 font-display text-xs uppercase tracking-wide ${
              counts[c] === SQUAD_REQUIREMENTS[c]
                ? CATEGORY_STYLES[c]
                : "border border-line bg-transparent text-text-soft"
            }`}
          >
            {CATEGORY_LABEL[c]} · {counts[c]}/{SQUAD_REQUIREMENTS[c]}
          </span>
        ))}
        {!locked && (
          <button
            type="button"
            disabled={!canSave || isPending}
            onClick={save}
            className="ml-auto rounded-full bg-amarillo px-4 py-2.5 font-display text-sm uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
          >
            {isPending ? "Guardando…" : `Guardar (${total}/${SQUAD_SIZE})`}
          </button>
        )}
      </div>
      {feedback && (
        <p
          className={`mt-2 text-sm ${
            feedback.type === "ok" ? "text-verde-deep" : "text-rosa"
          }`}
        >
          {feedback.text}
        </p>
      )}

      {!locked && (
        <div className="mt-4 flex flex-col gap-2 sm:flex-row">
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Buscar corredor o país…"
            className="w-full rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
          />
        </div>
      )}

      <div className="mt-3 flex flex-wrap items-center gap-2">
        <span className="text-xs text-text-soft">Color:</span>
        <button
          type="button"
          onClick={() => setCategoryFilter("all")}
          className={`rounded-full border px-3 py-1.5 font-display text-xs uppercase tracking-wide ${
            categoryFilter === "all"
              ? "border-verde-deep bg-verde-deep text-on-accent"
              : "border-line bg-surface text-text-soft"
          }`}
        >
          Todos
        </button>
        {CATEGORIES.map((c) => (
          <button
            key={c}
            type="button"
            onClick={() => setCategoryFilter((prev) => (prev === c ? "all" : c))}
            aria-pressed={categoryFilter === c}
            className={`rounded-full px-3 py-1.5 font-display text-xs uppercase tracking-wide transition ${CATEGORY_STYLES[c]} ${
              categoryFilter === c
                ? "ring-2 ring-offset-1 ring-verde-deep"
                : categoryFilter === "all"
                ? ""
                : "opacity-40"
            }`}
          >
            {CATEGORY_LABEL[c]}
          </button>
        ))}
      </div>

      <div className="mt-5 flex flex-col gap-4">
        {groups.map(([country, countryRiders]) => (
          <div key={country}>
            <h3 className="font-display text-xs uppercase tracking-wide text-verde-deep">
              {country}
            </h3>
            <div className="mt-1.5 flex flex-col gap-1.5">
              {countryRiders.map((rider) => {
                const isSelected = selected.has(rider.id);
                const full =
                  !isSelected && counts[rider.category] >= SQUAD_REQUIREMENTS[rider.category];
                return (
                  <button
                    key={rider.id}
                    type="button"
                    disabled={locked || full}
                    onClick={() => toggle(rider)}
                    className={`flex items-center justify-between gap-3 rounded-xl border px-3.5 py-2.5 text-left transition ${
                      isSelected
                        ? "border-verde-deep bg-verde-deep/10"
                        : full || locked
                        ? "border-line bg-surface opacity-40"
                        : "border-line bg-surface hover:border-verde-deep/50"
                    }`}
                  >
                    <span className="min-w-0 flex-1 truncate text-base">{rider.name}</span>
                    <span
                      className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-display uppercase tracking-wide ${CATEGORY_STYLES[rider.category]}`}
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
UKT_MUNDIAL_V2_EOF

echo "  - src/components/mundial-subnav.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-subnav.tsx" <<'UKT_MUNDIAL_V2_EOF'
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const ITEMS = [
  { href: "/mundial/eleccion", label: "Elección de equipo" },
  { href: "/mundial/equipo", label: "Mi equipo" },
  { href: "/mundial/clasificacion", label: "Clasificación" },
  { href: "/mundial/perfil", label: "Perfil y mapa" },
];

const ADMIN_ITEMS = [
  { href: "/mundial/corredores", label: "Corredores" },
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
UKT_MUNDIAL_V2_EOF

echo "  - src/components/mundial-home-banner.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-home-banner.tsx" <<'UKT_MUNDIAL_V2_EOF'
import Image from "next/image";
import Link from "next/link";

// Ventana de visibilidad del banner: aparece hoy y se retira solo al
// empezar octubre, cuando el Mundial ya haya pasado. Para cambiar las
// fechas basta con editar estas dos constantes.
const BANNER_START = new Date("2026-09-01T00:00:00");
const BANNER_END = new Date("2026-10-01T00:00:00");

export default function MundialHomeBanner() {
  const now = new Date();
  if (now < BANNER_START || now >= BANNER_END) return null;

  return (
    <Link
      href="/mundial"
      className="group relative mb-6 block overflow-hidden rounded-2xl border border-line bg-surface transition hover:border-verde-deep/50"
    >
      <div className="mundial-stripe" />
      <div className="flex items-center gap-4 p-4 sm:p-5">
        <div className="h-14 w-14 shrink-0 overflow-hidden rounded-xl border-2 border-white bg-white sm:h-16 sm:w-16">
          <Image
            src="/mundial-logos/montreal-2026.png"
            alt="Mundial de Montreal 2026"
            width={64}
            height={64}
            className="h-full w-full object-cover"
          />
        </div>
        <div className="min-w-0 flex-1">
          <div className="font-display text-[11px] uppercase tracking-[0.16em] text-amarillo">
            Prueba especial
          </div>
          <div className="font-display text-base text-verde-deep sm:text-lg">
            Mundial de Montreal 2026
          </div>
          <p className="mt-0.5 text-xs text-text-soft sm:text-sm">
            Elige tus 6 corredores antes del 19 de septiembre →
          </p>
        </div>
        <span className="hidden shrink-0 rounded-full bg-amarillo px-4 py-2 font-display text-xs uppercase tracking-wide text-on-accent group-hover:bg-gold sm:inline-block">
          Entrar
        </span>
      </div>
    </Link>
  );
}
UKT_MUNDIAL_V2_EOF

echo "  - src/app/mundial/layout.tsx"
mkdir -p "src/app/mundial"
cat > "src/app/mundial/layout.tsx" <<'UKT_MUNDIAL_V2_EOF'
import type { ReactNode } from "react";
import Image from "next/image";
import { getSession } from "@/lib/auth";
import { getMundialEvent, formatEventDate, isPicksLocked } from "@/lib/mundial";
import MundialSubNav from "@/components/mundial-subnav";

export default async function MundialLayout({ children }: { children: ReactNode }) {
  const session = await getSession();
  const event = await getMundialEvent();
  const locked = event ? isPicksLocked(event.picks_lock_at) : false;

  return (
    <div className="mundial-scope">
      <div className="mundial-stripe" />
      <div className="mx-auto max-w-3xl px-5 py-8">
        <div className="flex items-center gap-4">
          <div className="h-16 w-16 shrink-0 overflow-hidden rounded-2xl border-2 border-white bg-white">
            <Image
              src="/mundial-logos/montreal-2026.png"
              alt="Mundial de Montreal 2026"
              width={64}
              height={64}
              className="h-full w-full object-cover"
            />
          </div>
          <div className="min-w-0">
            <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
              <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
              Prueba especial
            </div>
            <h1 className="text-xl text-verde-deep">
              {event?.name ?? "Mundial de Montreal 2026"}
            </h1>
            <div className="mt-1 flex items-center gap-1.5 text-[11px] text-text-soft">
              <span>Organiza</span>
              <Image
                src="/mundial-logos/uci.png"
                alt="UCI"
                width={54}
                height={24}
                className="h-4 w-auto rounded-sm bg-white px-1 py-0.5"
              />
            </div>
          </div>
        </div>

        {event?.picks_lock_at && (
          <p
            className={`mt-3 font-display text-xs uppercase tracking-wide ${
              locked ? "text-rosa" : "text-verde"
            }`}
          >
            {locked
              ? "Los fichajes están cerrados."
              : `Fichajes abiertos hasta ${formatEventDate(event.picks_lock_at)}.`}
          </p>
        )}

        <div className="mt-5">
          <MundialSubNav isAdmin={session?.role === "admin"} />
        </div>

        <div className="mt-6 pb-10">{children}</div>
      </div>
    </div>
  );
}
UKT_MUNDIAL_V2_EOF

echo "  - src/app/mundial/page.tsx"
mkdir -p "src/app/mundial"
cat > "src/app/mundial/page.tsx" <<'UKT_MUNDIAL_V2_EOF'
import { redirect } from "next/navigation";

// La portada del Mundial es el propio menú de pestañas (ver layout.tsx);
// aquí solo redirigimos a la pantalla de partida.
export default function MundialPage() {
  redirect("/mundial/eleccion");
}
UKT_MUNDIAL_V2_EOF

echo "  - src/app/mundial/eleccion/page.tsx"
mkdir -p "src/app/mundial/eleccion"
cat > "src/app/mundial/eleccion/page.tsx" <<'UKT_MUNDIAL_V2_EOF'
import { getSession } from "@/lib/auth";
import { sql } from "@/lib/db";
import MundialSquadSelector, {
  type MundialRider,
} from "@/components/mundial-squad-selector";
import { getMundialEvent, isPicksLocked } from "@/lib/mundial";

export default async function MundialEleccionPage() {
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

  const locked = isPicksLocked(event.picks_lock_at);

  const riders = (await sql`
    select id, name, team, category
    from special_event_riders
    where event_id = ${event.id}
    order by team, name
  `) as MundialRider[];

  const picks = (await sql`
    select rider_id from special_event_picks
    where event_id = ${event.id} and user_id = ${session.userId}
  `) as { rider_id: string }[];

  const squads = (await sql`
    select team_name from special_event_squads
    where event_id = ${event.id} and user_id = ${session.userId}
  `) as { team_name: string }[];

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Elección de equipo</h2>
      <p className="mt-1 text-sm text-text-soft">
        Ponle un nombre a tu equipo y elige 6 corredores de la lista cerrada: 1
        Amarillo, 2 Rosas y 3 Verdes. Puedes cambiarlo cuantas veces quieras
        hasta la fecha límite.
      </p>

      <div className="mt-4 rounded-2xl bg-surface p-4">
        {riders.length === 0 ? (
          <p className="text-sm text-text-soft">
            Todavía no hay lista de corredores para esta prueba.
          </p>
        ) : (
          <MundialSquadSelector
            riders={riders}
            initialSelectedIds={picks.map((p) => p.rider_id)}
            initialTeamName={squads[0]?.team_name ?? ""}
            locked={locked}
          />
        )}
      </div>
    </section>
  );
}
UKT_MUNDIAL_V2_EOF

echo "  - src/app/mundial/equipo/page.tsx"
mkdir -p "src/app/mundial/equipo"
cat > "src/app/mundial/equipo/page.tsx" <<'UKT_MUNDIAL_V2_EOF'
import Link from "next/link";
import { getSession } from "@/lib/auth";
import { sql } from "@/lib/db";
import {
  CATEGORY_LABEL,
  getMundialEvent,
  isPicksLocked,
  pointsForPosition,
  type RiderCategory,
} from "@/lib/mundial";

type PickRow = {
  name: string;
  team: string | null;
  category: RiderCategory;
  multiplier: string;
  position: number | null;
};

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
};

export default async function MundialEquipoPage() {
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

  const locked = isPicksLocked(event.picks_lock_at);

  const squads = await sql`
    select team_name from special_event_squads
    where event_id = ${event.id} and user_id = ${session.userId}
  `;
  const teamName = squads[0]?.team_name as string | undefined;

  const picks = (await sql`
    select r.name, r.team, r.category, r.multiplier, res.position
    from special_event_picks p
    join special_event_riders r on r.id = p.rider_id
    left join special_event_results res
      on res.event_id = p.event_id and res.rider_id = p.rider_id
    where p.event_id = ${event.id} and p.user_id = ${session.userId}
    order by r.category, r.name
  `) as PickRow[];

  const total = picks.reduce(
    (sum, p) => sum + pointsForPosition(p.position) * Number(p.multiplier),
    0
  );

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Mi equipo</h2>

      {picks.length === 0 ? (
        <div className="mt-4 rounded-2xl border border-dashed border-line bg-surface p-6 text-center text-sm text-text-soft">
          Todavía no has fichado a nadie.{" "}
          <Link href="/mundial/eleccion" className="text-verde-deep underline">
            Elige tu equipo
          </Link>
          .
        </div>
      ) : (
        <div className="mt-4 rounded-2xl bg-surface p-4">
          <div className="flex items-center justify-between gap-3">
            <span className="font-display text-base text-verde-deep">
              {teamName || "(sin nombre)"}
            </span>
            <span className="font-display text-lg text-amarillo">
              {total.toFixed(1)} pts
            </span>
          </div>
          <p className="mt-1 text-xs text-text-soft">{session.displayName}</p>

          <div className="mt-4 flex flex-col gap-1.5">
            {picks.map((p, i) => (
              <div
                key={i}
                className="flex items-center justify-between gap-3 rounded-xl border border-line bg-[var(--bg)] px-3.5 py-2.5"
              >
                <span className="min-w-0 flex-1 truncate">
                  <span className="truncate text-base">{p.name}</span>
                  {p.team && <span className="ml-2 text-xs text-text-soft">{p.team}</span>}
                </span>
                <span
                  className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-display uppercase tracking-wide ${CATEGORY_STYLES[p.category]}`}
                >
                  {CATEGORY_LABEL[p.category]}
                </span>
              </div>
            ))}
          </div>

          {!locked && (
            <Link
              href="/mundial/eleccion"
              className="mt-4 inline-block text-xs text-verde-deep underline underline-offset-2"
            >
              Cambiar equipo
            </Link>
          )}
        </div>
      )}
    </section>
  );
}
UKT_MUNDIAL_V2_EOF

echo "  - src/app/mundial/perfil/page.tsx"
mkdir -p "src/app/mundial/perfil"
cat > "src/app/mundial/perfil/page.tsx" <<'UKT_MUNDIAL_V2_EOF'
const STATS = [
  { label: "Fecha", value: "Domingo 27 de septiembre de 2026" },
  { label: "Distancia total", value: "273,4 km" },
  { label: "Desnivel total", value: "3.803 m" },
  { label: "Circuito final", value: "13,4 km, en el Mont Royal" },
  { label: "Vueltas al circuito", value: "≈ 12" },
  { label: "Desnivel por vuelta", value: "≈ 269 m" },
];

const CLIMBS = [
  {
    name: "Voie Camillien-Houde",
    detail: "2,3 km al 6,2% de media — la ascensión principal del circuito, varias veces por vuelta.",
  },
  {
    name: "Côte de la Polytechnique",
    detail: "Corta pero muy dura, con rampas por encima del 11% en su tramo central.",
  },
  {
    name: "Avenue du Parc (meta)",
    detail: "Falso llano en ascenso hasta la línea de meta — decide la carrera al sprint o en solitario según cómo llegue el grupo.",
  },
];

export default function MundialPerfilPage() {
  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Perfil y mapa de la carrera</h2>
      <p className="mt-1 max-w-prose text-sm text-text-soft">
        La prueba en línea élite masculina sale de Brossard (región de la
        Montérégie), cruza el puente Samuel De Champlain hacia Montreal y
        termina con varias vueltas a un circuito exigente alrededor del
        Mont Royal.
      </p>

      <div className="mt-4 grid grid-cols-2 gap-2.5 sm:grid-cols-3">
        {STATS.map((s) => (
          <div key={s.label} className="rounded-xl border border-line bg-surface p-3">
            <div className="text-[11px] uppercase tracking-wide text-text-soft">
              {s.label}
            </div>
            <div className="mt-0.5 font-display text-sm text-verde-deep">{s.value}</div>
          </div>
        ))}
      </div>

      <h3 className="mt-6 font-display text-xs uppercase tracking-wide text-verde-deep">
        Puntos clave del circuito
      </h3>
      <div className="mt-2 flex flex-col gap-2">
        {CLIMBS.map((c) => (
          <div key={c.name} className="rounded-xl border border-line bg-surface p-3.5">
            <div className="font-display text-sm text-amarillo">{c.name}</div>
            <p className="mt-1 text-[13px] leading-relaxed text-text-soft">{c.detail}</p>
          </div>
        ))}
      </div>

      <div className="mt-6 rounded-2xl border border-dashed border-line bg-surface p-4 text-center">
        <p className="text-sm text-text-soft">
          Para el mapa interactivo y el perfil de altimetría oficiales, consulta
          la web del evento:
        </p>
        <a
          href="https://www.montreal2026.org/en/challenge/mens-elite/"
          target="_blank"
          rel="noopener noreferrer"
          className="mt-2 inline-flex items-center gap-1 font-display text-xs uppercase tracking-wide text-verde-deep underline underline-offset-2"
        >
          Web oficial — Men&apos;s Elite Road Race ↗
        </a>
      </div>

      <p className="mt-4 text-[11px] text-text-faint">
        Fuentes:{" "}
        <a
          href="https://en.wikipedia.org/wiki/2026_UCI_Road_World_Championships"
          target="_blank"
          rel="noopener noreferrer"
          className="underline underline-offset-2"
        >
          Wikipedia
        </a>{" "}
        ·{" "}
        <a
          href="https://procyclinguk.com/gp-montreal-2026-route-guide-world-championships-circuit-packs-in-4304-metres-of-climbing/"
          target="_blank"
          rel="noopener noreferrer"
          className="underline underline-offset-2"
        >
          ProCyclingUK
        </a>
      </p>
    </section>
  );
}
UKT_MUNDIAL_V2_EOF

echo "  - src/app/mundial/clasificacion/page.tsx"
mkdir -p "src/app/mundial/clasificacion"
cat > "src/app/mundial/clasificacion/page.tsx" <<'UKT_MUNDIAL_V2_EOF'
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getMundialEvent, isPicksLocked, pointsForPosition } from "@/lib/mundial";

type SquadRow = {
  user_id: string;
  display_name: string;
  team_name: string | null;
};

type PickRow = {
  user_id: string;
  rider_name: string;
  team: string | null;
  multiplier: string;
  position: number | null;
};

export default async function MundialClasificacionPage() {
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

  const locked = isPicksLocked(event.picks_lock_at);

  const squadRows = (await sql`
    select s.user_id, u.display_name, s.team_name
    from special_event_squads s
    join users u on u.id = s.user_id
    where s.event_id = ${event.id}
    order by u.display_name
  `) as SquadRow[];

  const pickRows = (await sql`
    select
      p.user_id,
      r.name as rider_name,
      r.team,
      r.multiplier,
      res.position
    from special_event_picks p
    join special_event_riders r on r.id = p.rider_id
    left join special_event_results res
      on res.event_id = p.event_id and res.rider_id = p.rider_id
    where p.event_id = ${event.id}
  `) as PickRow[];

  const picksByUser = new Map<string, PickRow[]>();
  for (const row of pickRows) {
    if (!picksByUser.has(row.user_id)) picksByUser.set(row.user_id, []);
    picksByUser.get(row.user_id)!.push(row);
  }

  const standings = squadRows
    .map((s) => {
      const picks = picksByUser.get(s.user_id) ?? [];
      const total = picks.reduce(
        (sum, p) => sum + pointsForPosition(p.position) * Number(p.multiplier),
        0
      );
      return {
        userId: s.user_id,
        displayName: s.display_name,
        teamName: s.team_name || "(sin nombre)",
        total,
        picks,
      };
    })
    .sort((a, b) => b.total - a.total);

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Clasificación</h2>
      <p className="mt-1 text-sm text-text-soft">
        Independiente de la clasificación general de las clásicas.
        {!locked && (
          <>
            {" "}
            Mientras los fichajes estén abiertos, solo se ve el nombre de cada
            equipo — los corredores elegidos se revelan al cerrarse el plazo.
          </>
        )}
      </p>

      <div className="mt-6 flex flex-col gap-3">
        {standings.map((s, i) => {
          const revealed = locked || s.userId === session.userId;
          return (
            <div
              key={s.userId}
              className="rounded-2xl border border-line bg-surface p-4"
            >
              <div className="flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <span className="font-display text-sm text-verde-deep">
                    {i + 1}. {s.teamName}
                  </span>
                  <div className="text-[11px] text-text-soft">{s.displayName}</div>
                </div>
                <span className="shrink-0 font-display text-lg text-amarillo">
                  {s.total.toFixed(1)}
                </span>
              </div>
              {revealed ? (
                <div className="mt-2 flex flex-wrap gap-1.5 text-xs text-text-soft">
                  {s.picks.map((p, j) => (
                    <span key={j} className="rounded-full border border-line px-2.5 py-1">
                      {p.rider_name} · {(pointsForPosition(p.position) * Number(p.multiplier)).toFixed(1)}
                    </span>
                  ))}
                </div>
              ) : (
                <p className="mt-2 text-[11px] text-text-faint">
                  Equipo oculto hasta que se cierren los fichajes.
                </p>
              )}
            </div>
          );
        })}
        {standings.length === 0 && (
          <p className="text-sm text-text-soft">
            Todavía no hay fichajes registrados para esta prueba.
          </p>
        )}
      </div>
    </section>
  );
}
UKT_MUNDIAL_V2_EOF

echo "  - src/app/mundial/corredores/page.tsx"
mkdir -p "src/app/mundial/corredores"
cat > "src/app/mundial/corredores/page.tsx" <<'UKT_MUNDIAL_V2_EOF'
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
    <section>
      <h2 className="font-display text-sm text-verde-deep">Lista cerrada de corredores</h2>
      <p className="mt-1 max-w-prose text-sm text-text-soft">
        Añade aquí a los corredores convocados para el Mundial y clasifícalos
        en Amarillo, Rosa o Verde. Por defecto entran en Verde. Esta lista es
        propia del Mundial: no toca la base de datos de las clásicas.
      </p>

      <MundialRidersManager initialRiders={riders} />
    </section>
  );
}
UKT_MUNDIAL_V2_EOF

echo "  - src/app/mundial/resultados/page.tsx"
mkdir -p "src/app/mundial/resultados"
cat > "src/app/mundial/resultados/page.tsx" <<'UKT_MUNDIAL_V2_EOF'
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
    <section>
      <h2 className="font-display text-sm text-verde-deep">Resultados</h2>
      <p className="mt-1 max-w-prose text-sm text-text-soft">
        Introduce el puesto final (1-20) de cada corredor de la lista cerrada.
        Deja el campo vacío si no acabó entre los 20 primeros.
      </p>

      <MundialResultsForm initialRiders={riders} />
    </section>
  );
}
UKT_MUNDIAL_V2_EOF

echo "  - src/app/page.tsx"
mkdir -p "src/app"
cat > "src/app/page.tsx" <<'UKT_MUNDIAL_V2_EOF'
import Link from "next/link";
import Logo from "@/components/logo";
import CobbleBackground from "@/components/cobble-background";
import MundialHomeBanner from "@/components/mundial-home-banner";

export default function Home() {
  return (
    <>
      <section className="relative overflow-hidden px-5 py-14 text-[var(--hero-text)] sm:py-20">
        <CobbleBackground cell={0.13} seed={7} />
        <div
          className="pointer-events-none absolute inset-0"
          style={{
            background:
              "radial-gradient(120% 90% at 30% 20%, rgba(4,16,10,0.72), rgba(4,16,10,0.25) 55%, rgba(4,16,10,0.55))",
          }}
        />
        <div className="relative mx-auto max-w-3xl">
          <span className="inline-block rounded-full border border-white/40 px-3 py-1 font-display text-[11px] uppercase tracking-[0.16em]">
            Reglamento oficial · 2027
          </span>
          <h1 className="mt-5">
            <Logo
              className="h-16 w-auto sm:h-20"
              color="var(--hero-text)"
            />
          </h1>
          <div className="mt-3 font-display text-sm uppercase tracking-wide text-amarillo">
            Udaberriko Klasiko Txirrindulariak
          </div>
          <p className="mt-1 font-display text-xl normal-case">
            La porra de las Clásicas de Primavera
          </p>
          <p className="mt-5 max-w-xl border-l-2 border-amarillo pl-4 text-sm leading-relaxed text-white/90">
            Doce clásicas del World Tour, de finales de febrero a finales de
            abril. Elige tu equipo, sigue el calendario y pelea la general con
            la cuadrilla.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link
              href="/signup"
              className="rounded-full bg-amarillo px-5 py-2.5 font-display text-xs uppercase tracking-wide text-on-accent hover:bg-gold"
            >
              Apuntarme a la porra
            </Link>
            <Link
              href="/reglamento"
              className="rounded-full border border-white/40 px-5 py-2.5 font-display text-xs uppercase tracking-wide text-white"
            >
              Ver el reglamento
            </Link>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-3xl px-5 py-12">
        <MundialHomeBanner />
        <div className="grid gap-4 sm:grid-cols-3">
          <InfoCard n="12" label="Carreras" />
          <InfoCard n="12" label="Corredores por equipo" />
          <InfoCard n="1" label="Duelo Sprint por carrera" />
        </div>
      </section>
    </>
  );
}

function InfoCard({ n, label }: { n: string; label: string }) {
  return (
    <div className="rounded-xl border border-line bg-surface px-4 py-5 text-center">
      <div className="font-display text-3xl font-bold text-verde">{n}</div>
      <div className="mt-1 text-[11px] uppercase tracking-wide text-text-soft">
        {label}
      </div>
    </div>
  );
}
UKT_MUNDIAL_V2_EOF

echo "  - src/components/site-header.tsx"
mkdir -p "src/components"
cat > "src/components/site-header.tsx" <<'UKT_MUNDIAL_V2_EOF'
import Image from "next/image";
import Link from "next/link";
import type { SessionPayload } from "@/lib/auth";
import LogoutButton from "@/components/logout-button";
import MobileNav from "@/components/mobile-nav";
import Logo from "@/components/logo";

type NavItem = { href: string; label: string; icon?: string };

export default function SiteHeader({
  session,
}: {
  session: SessionPayload | null;
}) {
  const navItems: NavItem[] = [
    { href: "/reglamento", label: "Reglamento" },
    { href: "/calendario", label: "Calendario" },
  ];
  if (session?.status === "approved") {
    navItems.push(
      { href: "/mi-equipo", label: "Mi equipo" },
      { href: "/clasificacion", label: "Clasificación" },
      { href: "/mundial", label: "Mundial", icon: "/mundial-logos/rainbow-flag.png" }
    );
  }
  if (session?.role === "admin" || session?.sanedrin) {
    navItems.push({ href: "/corredores", label: "Corredores" });
  }
  if (session?.role === "admin") {
    navItems.push({ href: "/admin", label: "Admin" });
  }

  return (
    <header className="sticky top-0 z-20 relative border-b border-line bg-[var(--bg)]/92 backdrop-blur-sm">
      <div className="mx-auto flex max-w-4xl items-center justify-between gap-4 px-5 py-2.5">
        <Link href="/" aria-label="UKT — Inicio" className="shrink-0">
          <Logo className="h-8 w-auto sm:h-9" />
        </Link>

        <nav className="hidden items-center gap-1 sm:flex">
          {navItems.map((item) => (
            <NavLink key={item.href} href={item.href} icon={item.icon}>
              {item.label}
            </NavLink>
          ))}
          <AuthActions session={session} />
        </nav>

        <MobileNav items={navItems}>
          <AuthActions session={session} />
        </MobileNav>
      </div>
    </header>
  );
}

function AuthActions({ session }: { session: SessionPayload | null }) {
  if (session) {
    return <LogoutButton />;
  }
  return (
    <div className="flex items-center gap-2 sm:gap-2">
      <NavLink href="/login">Entrar</NavLink>
      <Link
        href="/signup"
        className="rounded-full bg-amarillo px-4 py-2.5 text-center font-display text-xs uppercase tracking-wide text-on-accent hover:bg-gold sm:ml-1 sm:px-3.5 sm:py-2"
      >
        Crear cuenta
      </Link>
    </div>
  );
}

function NavLink({
  href,
  icon,
  children,
}: {
  href: string;
  icon?: string;
  children: React.ReactNode;
}) {
  return (
    <Link
      href={href}
      className="flex items-center gap-1.5 rounded-full px-3.5 py-2 font-display text-xs uppercase tracking-wide text-[var(--pill-text)] hover:bg-[var(--pill-bg)]"
    >
      {icon && <Image src={icon} alt="" width={16} height={16} className="rounded-full" />}
      {children}
    </Link>
  );
}
UKT_MUNDIAL_V2_EOF

echo "  - src/components/mobile-nav.tsx"
mkdir -p "src/components"
cat > "src/components/mobile-nav.tsx" <<'UKT_MUNDIAL_V2_EOF'
"use client";

import Image from "next/image";
import Link from "next/link";
import { useState } from "react";

type NavItem = { href: string; label: string; icon?: string };

export default function MobileNav({
  items,
  children,
}: {
  items: NavItem[];
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(false);

  return (
    <div className="sm:hidden">
      <button
        type="button"
        aria-label={open ? "Cerrar menú" : "Abrir menú"}
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
        className="flex h-10 w-10 items-center justify-center rounded-full border border-line text-text"
      >
        {open ? (
          <svg
            width="18"
            height="18"
            viewBox="0 0 18 18"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
          >
            <path d="M2 2l14 14M16 2L2 16" />
          </svg>
        ) : (
          <svg
            width="20"
            height="14"
            viewBox="0 0 20 14"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
          >
            <path d="M1 1h18M1 7h18M1 13h18" />
          </svg>
        )}
      </button>

      {open && (
        <div className="absolute inset-x-0 top-full z-30 border-b border-line bg-[var(--bg)] px-5 pb-4 pt-1 shadow-lg">
          <nav
            className="flex flex-col divide-y divide-line"
            onClick={() => setOpen(false)}
          >
            {items.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="flex items-center gap-2 py-3.5 font-display text-base uppercase tracking-wide text-text"
              >
                {item.icon && (
                  <Image src={item.icon} alt="" width={18} height={18} className="rounded-full" />
                )}
                {item.label}
              </Link>
            ))}
          </nav>
          <div
            className="mt-3 flex flex-col items-stretch gap-2 border-t border-line pt-3"
            onClick={() => setOpen(false)}
          >
            {children}
          </div>
        </div>
      )}
    </div>
  );
}
UKT_MUNDIAL_V2_EOF

echo "  - src/app/globals.css"
mkdir -p "src/app"
cat > "src/app/globals.css" <<'UKT_MUNDIAL_V2_EOF'
@import "tailwindcss";

/* ---------------------------------------------------------------
   UKT — identidad de marca (Udaberriko Klasiko Txirrindulariak)
   Adoquinado + verde de pelotón. Tema único (sin variante clara):
   la marca no define un modo claro, así que se usa el mismo verde
   oscuro en toda la app.
   --------------------------------------------------------------- */

:root {
  /* --- Superficies (escala de verdes de la marca) --- */
  --bg: #0d2c20; /* ukt-green-800: fondo base de la app */
  --surface: #123c2b; /* ukt-green-700: tarjetas */
  --surface-2: #1a4c36; /* ukt-green-600: hover / superficie secundaria */
  --bg-app-gradient: linear-gradient(160deg, #0d2c20 0%, #17422f 55%, #0f3325 100%);

  /* --- Texto --- */
  --text: #eef3e7; /* ukt-bone */
  --text-soft: rgba(238, 243, 231, 0.7);
  --text-faint: rgba(238, 243, 231, 0.45);
  --line: rgba(238, 243, 231, 0.14);

  /* --- Acentos de marca --- */
  --accent-verde: #5fc79b; /* ukt-mint-400: acento de información */
  --accent-verde-deep: #5fc79b; /* mismo menta, para títulos/labels con más peso */
  --accent-amarillo: #e9c03a; /* ukt-yellow-400: acción principal */
  --accent-gold: #c8901a; /* ukt-gold-500: hover del botón principal */
  --accent-rosa: #f58fb0; /* ukt-pink-400: solo categoría / coeficiente */
  --on-accent: #123c2b; /* texto sobre cualquier acento sólido (nunca blanco) */

  /* --- Cabecera / hero con textura de adoquinado --- */
  --hero-bg-1: #071a11; /* ukt-green-950 */
  --hero-bg-2: #123c2b; /* ukt-green-700 */
  --hero-text: #eef3e7;

  --pill-bg: rgba(238, 243, 231, 0.08);
  --pill-text: #eef3e7;
  --shadow: rgba(4, 16, 10, 0.45);
}

@theme inline {
  --color-bg: var(--bg);
  --color-surface: var(--surface);
  --color-surface-2: var(--surface-2);
  --color-text: var(--text);
  --color-text-soft: var(--text-soft);
  --color-line: var(--line);
  --color-verde: var(--accent-verde);
  --color-verde-deep: var(--accent-verde-deep);
  --color-amarillo: var(--accent-amarillo);
  --color-gold: var(--accent-gold);
  --color-rosa: var(--accent-rosa);
  --color-on-accent: var(--on-accent);
  --font-display: var(--font-oswald);
  --font-body: var(--font-nunito);
  --font-logo: var(--font-archivo);
}

body {
  margin: 0;
  background: var(--bg-app-gradient);
  color: var(--text);
  font-family: var(--font-body), sans-serif;
}

h1,
h2,
h3,
.font-display {
  font-family: var(--font-display), sans-serif;
  text-transform: uppercase;
  letter-spacing: 0.02em;
  text-wrap: balance;
}

.font-logo {
  font-family: var(--font-logo), "Arial Black", sans-serif;
  letter-spacing: -0.02em;
  line-height: 0.8;
}

/* ---------------------------------------------------------------
   Mundial de Montreal — prueba especial, look distinto del resto
   de la app. Solo sobreescribe fondo/superficies/línea/acento de
   cabeceras: los colores de categoría (amarillo/rosa/verde) se
   dejan intactos para que signifiquen lo mismo en todas partes.
   --------------------------------------------------------------- */
.mundial-scope {
  --bg: #12131d;
  --surface: #1b1d2c;
  --surface-2: #262842;
  --bg-app-gradient: linear-gradient(160deg, #12131d 0%, #1a1c2e 55%, #101120 100%);
  --line: rgba(238, 243, 231, 0.14);
  --accent-verde-deep: #4fa8e6;
  --pill-bg: rgba(79, 168, 230, 0.12);
  background: var(--bg-app-gradient);
  min-height: 100%;
}

.mundial-stripe {
  height: 6px;
  background: linear-gradient(
    to right,
    #007abe 0% 20%,
    #d92933 20% 40%,
    #181719 40% 60%,
    #ffec00 60% 80%,
    #39a640 80% 100%
  );
}
UKT_MUNDIAL_V2_EOF

echo "  - public/mundial-logos/rainbow-flag.png"
mkdir -p "public/mundial-logos"
base64 -d > "public/mundial-logos/rainbow-flag.png" <<'UKT_MUNDIAL_V2_B64_EOF'
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
UKT_MUNDIAL_V2_B64_EOF


echo ""
echo "Archivos escritos. Creando commit..."
git add -A
git commit -m "Amplía el Mundial de Montreal: submenú, nombre de equipo, tema propio

Añade pantallas separadas (Mi equipo, Elección de equipo, Clasificación,
Perfil y mapa de la carrera), nombre de equipo por jugador (oculto a los
demás participantes hasta que se cierren los fichajes), un tema visual
distinto del resto de la app, el logo arcoíris en el menú superior y un
banner de aviso en la portada visible hasta octubre."
git push

echo ""
echo "Listo. Antes de abrir la web, en el editor SQL de Neon ejecuta:"
echo "  db/mundial_migration_v2.sql   (añade la tabla de nombres de equipo)"
echo ""
echo "(Las tablas y los 194 corredores de mundial_migration.sql y"
echo "mundial_riders_seed.sql ya deberían estar cargados de antes)."
