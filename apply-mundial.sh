#!/usr/bin/env bash
set -euo pipefail

# apply-mundial.sh — añade la prueba especial "Mundial de Montreal" a UKT.
# Ejecuta esto DESDE LA RAÍZ del repo (donde está db/schema.sql), con el
# Codespace ya abierto y en la rama que quieras actualizar (normalmente main).

if [ ! -f "db/schema.sql" ]; then
  echo "Error: no se encuentra db/schema.sql en el directorio actual."
  echo "Ejecuta este script desde la raíz del repo clasicas-de-primavera."
  exit 1
fi

echo "Aplicando la funcionalidad 'Mundial de Montreal'..."

echo "  - src/lib/mundial.ts"
mkdir -p "src/lib"
cat > "src/lib/mundial.ts" <<'UKT_MUNDIAL_EOF'
import type { RiderCategory } from "./riders";
export type { RiderCategory };

// Todo lo de este fichero es deliberadamente independiente de lib/riders.ts:
// el Mundial de Montreal es una prueba única y separada de la porra de
// clásicas (mismo login, misma web, pero ni corredores ni puntuación se
// mezclan con la general).

export const MUNDIAL_SLUG = "montreal-2026";

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
UKT_MUNDIAL_EOF

echo "  - src/app/api/mundial/riders/route.ts"
mkdir -p "src/app/api/mundial/riders"
cat > "src/app/api/mundial/riders/route.ts" <<'UKT_MUNDIAL_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { CATEGORY_MULTIPLIER, MUNDIAL_SLUG } from "@/lib/mundial";

const BodySchema = z.object({
  name: z.string().trim().min(1).max(120),
  team: z.string().trim().max(120).optional().nullable(),
});

export async function POST(request: Request) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Nombre del corredor no válido." }, { status: 400 });
  }

  const events = await sql`select id from special_events where slug = ${MUNDIAL_SLUG}`;
  const eventId = events[0]?.id;
  if (!eventId) {
    return NextResponse.json({ error: "No se encuentra el evento del Mundial." }, { status: 500 });
  }

  const rows = await sql`
    insert into special_event_riders (event_id, name, team, category, multiplier)
    values (${eventId}, ${parsed.data.name}, ${parsed.data.team ?? null}, 'verde', ${CATEGORY_MULTIPLIER.verde})
    on conflict (event_id, name) do update set team = excluded.team
    returning id, name, team, category, multiplier
  `;

  return NextResponse.json({ ok: true, rider: rows[0] });
}
UKT_MUNDIAL_EOF

echo "  - src/app/api/mundial/riders/[id]/route.ts"
mkdir -p "src/app/api/mundial/riders/[id]"
cat > "src/app/api/mundial/riders/[id]/route.ts" <<'UKT_MUNDIAL_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { CATEGORY_MULTIPLIER } from "@/lib/mundial";

const PatchSchema = z.object({
  category: z.enum(["amarillo", "rosa", "verde"]),
});

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const { id } = await params;
  const body = await request.json().catch(() => null);
  const parsed = PatchSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Categoría inválida." }, { status: 400 });
  }

  const multiplier = CATEGORY_MULTIPLIER[parsed.data.category];
  await sql`
    update special_event_riders
    set category = ${parsed.data.category}, multiplier = ${multiplier}
    where id = ${id}
  `;

  return NextResponse.json({ ok: true, category: parsed.data.category, multiplier });
}

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const { id } = await params;
  await sql`delete from special_event_riders where id = ${id}`;

  return NextResponse.json({ ok: true });
}
UKT_MUNDIAL_EOF

echo "  - src/app/api/mundial/picks/route.ts"
mkdir -p "src/app/api/mundial/picks"
cat > "src/app/api/mundial/picks/route.ts" <<'UKT_MUNDIAL_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql, transaction } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { isValidSquad, SQUAD_SIZE, MUNDIAL_SLUG, type RiderCategory } from "@/lib/mundial";

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
      { error: `El equipo del Mundial debe tener exactamente ${SQUAD_SIZE} corredores.` },
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
  ]);

  return NextResponse.json({ ok: true });
}
UKT_MUNDIAL_EOF

echo "  - src/app/api/mundial/results/route.ts"
mkdir -p "src/app/api/mundial/results"
cat > "src/app/api/mundial/results/route.ts" <<'UKT_MUNDIAL_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql, transaction } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { MUNDIAL_SLUG } from "@/lib/mundial";

// Una fila por corredor de la lista cerrada que acabó en el top 20;
// position: null borra su resultado (no puntuó / no acabó la carrera).
const BodySchema = z.object({
  results: z.array(
    z.object({
      riderId: z.string().uuid(),
      position: z.number().int().min(1).max(20).nullable(),
    })
  ),
});

export async function POST(request: Request) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Datos de resultados no válidos." }, { status: 400 });
  }

  const events = await sql`select id from special_events where slug = ${MUNDIAL_SLUG}`;
  const eventId = events[0]?.id;
  if (!eventId) {
    return NextResponse.json({ error: "No se encuentra el evento del Mundial." }, { status: 500 });
  }

  // Dos puestos no pueden repetirse: comprobamos duplicados antes de guardar.
  const positions = parsed.data.results
    .map((r) => r.position)
    .filter((p): p is number => p !== null);
  if (new Set(positions).size !== positions.length) {
    return NextResponse.json(
      { error: "Hay un puesto repetido entre dos corredores distintos." },
      { status: 400 }
    );
  }

  const queries = parsed.data.results.map((r) =>
    r.position === null
      ? sql`
          delete from special_event_results
          where event_id = ${eventId} and rider_id = ${r.riderId}
        `
      : sql`
          insert into special_event_results (event_id, rider_id, position)
          values (${eventId}, ${r.riderId}, ${r.position})
          on conflict (event_id, rider_id) do update set position = excluded.position
        `
  );

  await transaction(queries);

  return NextResponse.json({ ok: true });
}
UKT_MUNDIAL_EOF

echo "  - src/components/mundial-squad-selector.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-squad-selector.tsx" <<'UKT_MUNDIAL_EOF'
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
  locked,
}: {
  riders: MundialRider[];
  initialSelectedIds: string[];
  locked: boolean;
}) {
  const [selected, setSelected] = useState<Set<string>>(
    () => new Set(initialSelectedIds)
  );
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
    counts.amarillo === SQUAD_REQUIREMENTS.amarillo &&
    counts.rosa === SQUAD_REQUIREMENTS.rosa &&
    counts.verde === SQUAD_REQUIREMENTS.verde;

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return riders.filter((r) => {
      if (categoryFilter !== "all" && r.category !== categoryFilter) return false;
      if (!q) return true;
      return (
        r.name.toLowerCase().includes(q) || (r.team ?? "").toLowerCase().includes(q)
      );
    });
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

      <div className="mt-5 flex flex-col gap-1.5">
        {filtered.map((rider) => {
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
              <span className="min-w-0 flex-1 truncate">
                <span className="truncate text-base">{rider.name}</span>
                {rider.team && (
                  <span className="ml-2 text-xs text-text-soft">{rider.team}</span>
                )}
              </span>
              <span
                className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-display uppercase tracking-wide ${CATEGORY_STYLES[rider.category]}`}
              >
                {CATEGORY_LABEL[rider.category]}
              </span>
            </button>
          );
        })}
        {filtered.length === 0 && (
          <p className="text-sm text-text-soft">No hay corredores que coincidan.</p>
        )}
      </div>
    </div>
  );
}
UKT_MUNDIAL_EOF

echo "  - src/components/mundial-riders-manager.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-riders-manager.tsx" <<'UKT_MUNDIAL_EOF'
"use client";

import { useMemo, useState, useTransition } from "react";
import { CATEGORY_LABEL, type RiderCategory } from "@/lib/mundial";

export type MundialAdminRider = {
  id: string;
  name: string;
  team: string | null;
  category: RiderCategory;
  multiplier: number;
};

const CATEGORIES: RiderCategory[] = ["amarillo", "rosa", "verde"];

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
};

export default function MundialRidersManager({
  initialRiders,
}: {
  initialRiders: MundialAdminRider[];
}) {
  const [riders, setRiders] = useState(initialRiders);
  const [query, setQuery] = useState("");
  const [name, setName] = useState("");
  const [team, setTeam] = useState("");
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [isAdding, startAdding] = useTransition();
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return riders;
    return riders.filter(
      (r) => r.name.toLowerCase().includes(q) || (r.team ?? "").toLowerCase().includes(q)
    );
  }, [riders, query]);

  const counts = useMemo(() => {
    const c = { amarillo: 0, rosa: 0, verde: 0 };
    for (const r of riders) c[r.category]++;
    return c;
  }, [riders]);

  function addRider(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    setError(null);
    startAdding(async () => {
      const res = await fetch("/api/mundial/riders", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: name.trim(), team: team.trim() || null }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setError(data?.error ?? "No se pudo añadir el corredor.");
        return;
      }
      setRiders((rs) =>
        [...rs.filter((r) => r.id !== data.rider.id), data.rider].sort((a, b) =>
          a.name.localeCompare(b.name)
        )
      );
      setName("");
      setTeam("");
    });
  }

  function setCategory(riderId: string, category: RiderCategory) {
    const prev = riders;
    setPendingId(riderId);
    setRiders((rs) => rs.map((r) => (r.id === riderId ? { ...r, category } : r)));
    startTransition(async () => {
      const res = await fetch(`/api/mundial/riders/${riderId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ category }),
      });
      if (!res.ok) {
        setRiders(prev);
      }
      setPendingId(null);
    });
  }

  function removeRider(riderId: string) {
    const prev = riders;
    setRiders((rs) => rs.filter((r) => r.id !== riderId));
    startTransition(async () => {
      const res = await fetch(`/api/mundial/riders/${riderId}`, { method: "DELETE" });
      if (!res.ok) {
        setRiders(prev);
      }
    });
  }

  return (
    <div className="mt-6">
      <form
        onSubmit={addRider}
        className="flex flex-col gap-2 rounded-2xl bg-surface p-4 sm:flex-row"
      >
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Nombre del corredor"
          className="w-full rounded-full border border-line bg-[var(--bg)] px-4 py-2.5 text-base outline-none focus:border-verde"
        />
        <input
          type="text"
          value={team}
          onChange={(e) => setTeam(e.target.value)}
          placeholder="País / equipo (opcional)"
          className="w-full rounded-full border border-line bg-[var(--bg)] px-4 py-2.5 text-base outline-none focus:border-verde sm:max-w-[220px]"
        />
        <button
          type="submit"
          disabled={isAdding || !name.trim()}
          className="shrink-0 rounded-full bg-amarillo px-4 py-2.5 font-display text-xs uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
        >
          {isAdding ? "Añadiendo…" : "Añadir"}
        </button>
      </form>
      {error && <p className="mt-2 text-sm text-rosa">{error}</p>}

      <div className="mt-4 flex flex-wrap items-center gap-2 text-xs">
        {CATEGORIES.map((c) => (
          <span
            key={c}
            className={`rounded-full px-3 py-1.5 font-display uppercase tracking-wide ${CATEGORY_STYLES[c]}`}
          >
            {CATEGORY_LABEL[c]} · {counts[c]}
          </span>
        ))}
        <span className="ml-auto rounded-full border border-line px-3 py-1.5 text-text-soft">
          Total: {riders.length}
        </span>
      </div>

      <input
        type="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Buscar corredor o país…"
        className="mt-4 w-full rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
      />

      <div className="mt-4 flex flex-col gap-1.5">
        {filtered.map((rider) => (
          <div
            key={rider.id}
            className="flex items-center justify-between gap-3 rounded-xl border border-line bg-surface px-3.5 py-2.5"
          >
            <span className="min-w-0 flex-1 truncate">
              <span className="truncate text-base">{rider.name}</span>
              {rider.team && (
                <span className="ml-2 text-xs text-text-soft">{rider.team}</span>
              )}
            </span>
            <div className="flex shrink-0 items-center gap-1.5">
              {CATEGORIES.map((c) => (
                <button
                  key={c}
                  type="button"
                  disabled={isPending && pendingId === rider.id}
                  onClick={() => setCategory(rider.id, c)}
                  aria-pressed={rider.category === c}
                  title={CATEGORY_LABEL[c]}
                  className={`h-8 w-8 rounded-full border-2 transition ${
                    rider.category === c
                      ? `${CATEGORY_STYLES[c]} border-transparent`
                      : "border-line bg-transparent opacity-40 hover:opacity-70"
                  }`}
                />
              ))}
              <button
                type="button"
                onClick={() => removeRider(rider.id)}
                title="Eliminar"
                className="ml-1 h-8 w-8 rounded-full border border-line text-text-soft hover:border-rosa hover:text-rosa"
              >
                ×
              </button>
            </div>
          </div>
        ))}
        {filtered.length === 0 && (
          <p className="text-sm text-text-soft">
            No hay corredores todavía. Añade el primero arriba.
          </p>
        )}
      </div>
    </div>
  );
}
UKT_MUNDIAL_EOF

echo "  - src/components/mundial-results-form.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-results-form.tsx" <<'UKT_MUNDIAL_EOF'
"use client";

import { useState, useTransition } from "react";

export type ResultsRider = {
  id: string;
  name: string;
  team: string | null;
  position: number | null;
};

export default function MundialResultsForm({
  initialRiders,
}: {
  initialRiders: ResultsRider[];
}) {
  const [positions, setPositions] = useState<Record<string, string>>(() =>
    Object.fromEntries(
      initialRiders.map((r) => [r.id, r.position ? String(r.position) : ""])
    )
  );
  const [isPending, startTransition] = useTransition();
  const [feedback, setFeedback] = useState<
    { type: "ok" | "error"; text: string } | null
  >(null);

  function save() {
    setFeedback(null);
    const results = initialRiders.map((r) => {
      const raw = positions[r.id]?.trim();
      const position = raw ? Number(raw) : null;
      return {
        riderId: r.id,
        position: position && Number.isFinite(position) ? position : null,
      };
    });
    startTransition(async () => {
      const res = await fetch("/api/mundial/results", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ results }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setFeedback({ type: "error", text: data?.error ?? "No se pudo guardar." });
        return;
      }
      setFeedback({ type: "ok", text: "Resultados guardados." });
    });
  }

  return (
    <div className="mt-6">
      <div className="flex flex-col gap-1.5">
        {initialRiders.map((r) => (
          <div
            key={r.id}
            className="flex items-center justify-between gap-3 rounded-xl border border-line bg-surface px-3.5 py-2.5"
          >
            <span className="min-w-0 flex-1 truncate">
              <span className="truncate text-base">{r.name}</span>
              {r.team && <span className="ml-2 text-xs text-text-soft">{r.team}</span>}
            </span>
            <input
              type="number"
              min={1}
              max={20}
              value={positions[r.id] ?? ""}
              onChange={(e) =>
                setPositions((prev) => ({ ...prev, [r.id]: e.target.value }))
              }
              placeholder="Puesto"
              className="w-20 shrink-0 rounded-full border border-line bg-[var(--bg)] px-3 py-1.5 text-center text-sm outline-none focus:border-verde"
            />
          </div>
        ))}
        {initialRiders.length === 0 && (
          <p className="text-sm text-text-soft">Todavía no hay corredores en la lista.</p>
        )}
      </div>

      {initialRiders.length > 0 && (
        <button
          type="button"
          disabled={isPending}
          onClick={save}
          className="mt-4 rounded-full bg-amarillo px-4 py-2.5 font-display text-sm uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
        >
          {isPending ? "Guardando…" : "Guardar resultados"}
        </button>
      )}

      {feedback && (
        <p
          className={`mt-2 text-sm ${
            feedback.type === "ok" ? "text-verde-deep" : "text-rosa"
          }`}
        >
          {feedback.text}
        </p>
      )}
    </div>
  );
}
UKT_MUNDIAL_EOF

echo "  - src/app/mundial/page.tsx"
mkdir -p "src/app/mundial"
cat > "src/app/mundial/page.tsx" <<'UKT_MUNDIAL_EOF'
import Link from "next/link";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import MundialSquadSelector, {
  type MundialRider,
} from "@/components/mundial-squad-selector";
import { MUNDIAL_SLUG, formatEventDate } from "@/lib/mundial";

type EventRow = {
  id: string;
  name: string;
  event_date: string | null;
  picks_lock_at: string | null;
};

export default async function MundialPage() {
  const session = await getSession();
  if (!session) return null; // el proxy ya redirige a /login antes de llegar aquí

  const events = (await sql`
    select id, name, event_date, picks_lock_at
    from special_events where slug = ${MUNDIAL_SLUG}
  `) as EventRow[];
  const event = events[0];

  if (!event) {
    return (
      <div className="mx-auto max-w-3xl px-5 py-10">
        <h1 className="text-2xl text-verde-deep">Mundial de Montreal</h1>
        <p className="mt-4 text-sm text-text-soft">
          Todavía no se ha configurado esta prueba especial.
        </p>
      </div>
    );
  }

  const locked =
    Boolean(event.picks_lock_at) &&
    new Date(event.picks_lock_at as string).getTime() <= Date.now();

  const riders = (await sql`
    select id, name, team, category
    from special_event_riders
    where event_id = ${event.id}
    order by category, name
  `) as MundialRider[];

  const picks = (await sql`
    select rider_id from special_event_picks
    where event_id = ${event.id} and user_id = ${session.userId}
  `) as { rider_id: string }[];

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Prueba especial
      </div>
      <h1 className="text-2xl text-verde-deep">{event.name}</h1>
      <p className="mt-2 max-w-prose text-sm text-text-soft">
        Carrera única, independiente de la clasificación general de las
        clásicas.
        {event.event_date && <> Se corre el {formatEventDate(event.event_date)}.</>}{" "}
        Elige 6 corredores de la lista cerrada: 1 Amarillo, 2 Rosas y 3 Verdes.
      </p>

      {event.picks_lock_at && (
        <p
          className={`mt-2 font-display text-xs uppercase tracking-wide ${
            locked ? "text-rosa" : "text-verde"
          }`}
        >
          {locked
            ? "Los fichajes están cerrados."
            : `Fichajes abiertos hasta ${formatEventDate(event.picks_lock_at)}.`}
        </p>
      )}

      <div className="mt-6 flex flex-wrap gap-2">
        <Link
          href="/mundial/clasificacion"
          className="rounded-full border border-line bg-surface px-4 py-2 font-display text-xs uppercase tracking-wide text-text-soft hover:border-verde-deep/50"
        >
          Ver clasificación
        </Link>
        {session.role === "admin" && (
          <>
            <Link
              href="/mundial/corredores"
              className="rounded-full border border-line bg-surface px-4 py-2 font-display text-xs uppercase tracking-wide text-text-soft hover:border-verde-deep/50"
            >
              Gestionar corredores
            </Link>
            <Link
              href="/mundial/resultados"
              className="rounded-full border border-line bg-surface px-4 py-2 font-display text-xs uppercase tracking-wide text-text-soft hover:border-verde-deep/50"
            >
              Cargar resultados
            </Link>
          </>
        )}
      </div>

      <div className="mt-6 rounded-2xl bg-surface p-4">
        {riders.length === 0 ? (
          <p className="text-sm text-text-soft">
            Todavía no hay lista de corredores para esta prueba.
          </p>
        ) : (
          <MundialSquadSelector
            riders={riders}
            initialSelectedIds={picks.map((p) => p.rider_id)}
            locked={locked}
          />
        )}
      </div>
    </div>
  );
}
UKT_MUNDIAL_EOF

echo "  - src/app/mundial/corredores/page.tsx"
mkdir -p "src/app/mundial/corredores"
cat > "src/app/mundial/corredores/page.tsx" <<'UKT_MUNDIAL_EOF'
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
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Mundial de Montreal
      </div>
      <h1 className="text-2xl text-verde-deep">Lista cerrada de corredores</h1>
      <p className="mt-2 max-w-prose text-sm text-text-soft">
        Añade aquí a los corredores convocados para el Mundial y clasifícalos
        en Amarillo, Rosa o Verde. Por defecto entran en Verde. Esta lista es
        propia del Mundial: no toca la base de datos de las clásicas.
      </p>

      <MundialRidersManager initialRiders={riders} />
    </div>
  );
}
UKT_MUNDIAL_EOF

echo "  - src/app/mundial/clasificacion/page.tsx"
mkdir -p "src/app/mundial/clasificacion"
cat > "src/app/mundial/clasificacion/page.tsx" <<'UKT_MUNDIAL_EOF'
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { MUNDIAL_SLUG, pointsForPosition } from "@/lib/mundial";

type PickRow = {
  user_id: string;
  display_name: string;
  rider_name: string;
  team: string | null;
  category: string;
  multiplier: string;
  position: number | null;
};

export default async function MundialClasificacionPage() {
  const session = await getSession();
  if (!session) return null; // el proxy ya redirige a /login antes de llegar aquí

  const events = await sql`select id from special_events where slug = ${MUNDIAL_SLUG}`;
  const eventId = events[0]?.id;

  const rows = eventId
    ? ((await sql`
        select
          u.id as user_id,
          u.display_name,
          r.name as rider_name,
          r.team,
          r.category,
          r.multiplier,
          res.position
        from special_event_picks p
        join users u on u.id = p.user_id
        join special_event_riders r on r.id = p.rider_id
        left join special_event_results res
          on res.event_id = p.event_id and res.rider_id = p.rider_id
        where p.event_id = ${eventId}
        order by u.display_name, r.category
      `) as PickRow[])
    : [];

  const byUser = new Map<
    string,
    {
      displayName: string;
      total: number;
      picks: { name: string; team: string | null; points: number }[];
    }
  >();

  for (const row of rows) {
    if (!byUser.has(row.user_id)) {
      byUser.set(row.user_id, {
        displayName: row.display_name,
        total: 0,
        picks: [],
      });
    }
    const entry = byUser.get(row.user_id)!;
    const points = pointsForPosition(row.position) * Number(row.multiplier);
    entry.total += points;
    entry.picks.push({ name: row.rider_name, team: row.team, points });
  }

  const standings = Array.from(byUser.values()).sort((a, b) => b.total - a.total);

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Mundial de Montreal
      </div>
      <h1 className="text-2xl text-verde-deep">Clasificación</h1>
      <p className="mt-2 text-sm text-text-soft">
        Independiente de la clasificación general de las clásicas.
      </p>

      <div className="mt-6 flex flex-col gap-3">
        {standings.map((s, i) => (
          <div
            key={s.displayName}
            className="rounded-2xl border border-line bg-surface p-4"
          >
            <div className="flex items-center justify-between gap-3">
              <span className="font-display text-sm text-verde-deep">
                {i + 1}. {s.displayName}
              </span>
              <span className="font-display text-lg text-amarillo">
                {s.total.toFixed(1)}
              </span>
            </div>
            <div className="mt-2 flex flex-wrap gap-1.5 text-xs text-text-soft">
              {s.picks.map((p, j) => (
                <span key={j} className="rounded-full border border-line px-2.5 py-1">
                  {p.name} · {p.points.toFixed(1)}
                </span>
              ))}
            </div>
          </div>
        ))}
        {standings.length === 0 && (
          <p className="text-sm text-text-soft">
            Todavía no hay fichajes registrados para esta prueba.
          </p>
        )}
      </div>
    </div>
  );
}
UKT_MUNDIAL_EOF

echo "  - src/app/mundial/resultados/page.tsx"
mkdir -p "src/app/mundial/resultados"
cat > "src/app/mundial/resultados/page.tsx" <<'UKT_MUNDIAL_EOF'
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
UKT_MUNDIAL_EOF

echo "  - src/proxy.ts"
mkdir -p "src"
cat > "src/proxy.ts" <<'UKT_MUNDIAL_EOF'
import { NextRequest, NextResponse } from "next/server";
import { jwtVerify } from "jose";
import { SESSION_COOKIE } from "@/lib/auth";

// Routes that require an authenticated session at all.
const PROTECTED_PREFIXES = ["/mi-equipo", "/clasificacion", "/admin", "/pendiente", "/corredores", "/mundial"];
const ADMIN_PREFIX = "/admin";
const PUBLIC_AUTH_PATHS = ["/login", "/signup"];

async function readSession(token: string | undefined) {
  if (!token || !process.env.JWT_SECRET) return null;
  try {
    const { payload } = await jwtVerify(
      token,
      new TextEncoder().encode(process.env.JWT_SECRET)
    );
    return payload as {
      role?: string;
      status?: string;
    };
  } catch {
    return null;
  }
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const token = request.cookies.get(SESSION_COOKIE)?.value;
  const session = await readSession(token);

  const isProtected = PROTECTED_PREFIXES.some((p) => pathname.startsWith(p));
  const isAuthPage = PUBLIC_AUTH_PATHS.some((p) => pathname.startsWith(p));

  if (isAuthPage && session && session.status === "approved") {
    return NextResponse.redirect(new URL("/mi-equipo", request.url));
  }

  if (!isProtected) {
    return NextResponse.next();
  }

  if (!session) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("next", pathname);
    return NextResponse.redirect(loginUrl);
  }

  if (pathname.startsWith(ADMIN_PREFIX) && session.role !== "admin") {
    return NextResponse.redirect(new URL("/mi-equipo", request.url));
  }

  if (
    !pathname.startsWith("/pendiente") &&
    session.role !== "admin" &&
    session.status !== "approved"
  ) {
    return NextResponse.redirect(new URL("/pendiente", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/mi-equipo/:path*",
    "/clasificacion/:path*",
    "/admin/:path*",
    "/pendiente/:path*",
    "/corredores/:path*",
    "/mundial/:path*",
    "/login",
    "/signup",
  ],
};
UKT_MUNDIAL_EOF

echo "  - src/components/site-header.tsx"
mkdir -p "src/components"
cat > "src/components/site-header.tsx" <<'UKT_MUNDIAL_EOF'
import Link from "next/link";
import type { SessionPayload } from "@/lib/auth";
import LogoutButton from "@/components/logout-button";
import MobileNav from "@/components/mobile-nav";
import Logo from "@/components/logo";

type NavItem = { href: string; label: string };

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
      { href: "/mundial", label: "Mundial" }
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
            <NavLink key={item.href} href={item.href}>
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

function NavLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="rounded-full px-3.5 py-2 font-display text-xs uppercase tracking-wide text-[var(--pill-text)] hover:bg-[var(--pill-bg)]"
    >
      {children}
    </Link>
  );
}
UKT_MUNDIAL_EOF


echo ""
echo "Archivos escritos. Creando commit..."
git add -A
git commit -m "Añade prueba especial: Mundial de Montreal 2026

Nueva mini-funcionalidad aislada (tablas propias, lib propia) para una
carrera única fuera de la porra de clásicas: cada jugador elige 6
corredores (1 Amarillo + 2 Rosas + 3 Verdes) de una lista cerrada,
misma tabla de puntos, clasificación independiente. Fichajes cerrados
automáticamente el 19 de septiembre de 2026 a las 23:59 (hora de
España), antes de que empiece la semana del Mundial en Montreal."
git push

echo ""
echo "Listo. No olvides ejecutar db/mundial_migration.sql en el editor SQL"
echo "de Neon ANTES de abrir la web (crea las tablas nuevas y el evento)."
