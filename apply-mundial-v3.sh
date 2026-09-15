#!/usr/bin/env bash
set -euo pipefail

# apply-mundial-v3.sh — permite editar nombre/país de un corredor ya creado
# (por ejemplo, corregir "Mattias Skjelmose Jennow JENSEN" a "Skjelmose"),
# y añade una banderita de país antes del nombre en las listas de
# corredores (gestión de admin y elección de equipo).
#
# IMPORTANTE: este script NO trae ningún archivo .sql — no hace falta tocar
# nada en Neon para este cambio, solo son archivos de la aplicación.
#
# Ejecuta esto DESDE LA RAÍZ del repo (donde está db/schema.sql), con el
# Codespace ya abierto. Requiere haber aplicado antes apply-mundial.sh y
# apply-mundial-v2.sh.

if [ ! -f "db/schema.sql" ]; then
  echo "Error: no se encuentra db/schema.sql en el directorio actual."
  echo "Ejecuta este script desde la raíz del repo clasicas-de-primavera."
  exit 1
fi

echo "Aplicando la edición de corredores y banderas de país (v3)..."

echo "  - src/lib/mundial.ts"
mkdir -p "src/lib"
cat > "src/lib/mundial.ts" <<'UKT_MUNDIAL_V3_EOF'
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

// País (tal como se guarda en special_event_riders.team, en español) →
// código ISO 3166-1 alfa-2, para pintar la bandera antes del nombre. Los
// dos casos sin código real (atletas neutrales y el Equipo de Refugiados)
// se quedan sin bandera a propósito.
const COUNTRY_ISO: Record<string, string> = {
  Argelia: "DZ",
  Australia: "AU",
  Austria: "AT",
  Bélgica: "BE",
  Bermudas: "BM",
  Belice: "BZ",
  Brasil: "BR",
  Canadá: "CA",
  Chile: "CL",
  China: "CN",
  Colombia: "CO",
  "Costa Rica": "CR",
  Chipre: "CY",
  Chequia: "CZ",
  Dinamarca: "DK",
  Dominica: "DM",
  Ecuador: "EC",
  Eritrea: "ER",
  España: "ES",
  Estonia: "EE",
  Francia: "FR",
  "Gran Bretaña": "GB",
  "Guinea-Bisáu": "GW",
  Alemania: "DE",
  Grecia: "GR",
  Guatemala: "GT",
  Honduras: "HN",
  Hungría: "HU",
  Irlanda: "IE",
  Israel: "IL",
  Italia: "IT",
  Japón: "JP",
  Kazajistán: "KZ",
  "Arabia Saudí": "SA",
  Letonia: "LV",
  Luxemburgo: "LU",
  México: "MX",
  Mongolia: "MN",
  Mónaco: "MC",
  Mauricio: "MU",
  "Países Bajos": "NL",
  Noruega: "NO",
  "Nueva Zelanda": "NZ",
  Panamá: "PA",
  Polonia: "PL",
  Portugal: "PT",
  Rumanía: "RO",
  Sudáfrica: "ZA",
  Eslovenia: "SI",
  Serbia: "RS",
  Suiza: "CH",
  Eslovaquia: "SK",
  Suecia: "SE",
  Tailandia: "TH",
  Ucrania: "UA",
  Uruguay: "UY",
  "Estados Unidos": "US",
  Uzbekistán: "UZ",
  Venezuela: "VE",
};

function isoToFlagEmoji(iso: string) {
  return String.fromCodePoint(
    ...iso
      .toUpperCase()
      .split("")
      .map((c) => 127397 + c.charCodeAt(0))
  );
}

export function countryFlag(team: string | null | undefined): string {
  if (!team) return "";
  const iso = COUNTRY_ISO[team.trim()];
  return iso ? isoToFlagEmoji(iso) : "";
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
UKT_MUNDIAL_V3_EOF

echo "  - src/app/api/mundial/riders/[id]/route.ts"
mkdir -p "src/app/api/mundial/riders/[id]"
cat > "src/app/api/mundial/riders/[id]/route.ts" <<'UKT_MUNDIAL_V3_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { CATEGORY_MULTIPLIER, type RiderCategory } from "@/lib/mundial";

// Todos los campos son opcionales para poder reutilizar el mismo PATCH
// tanto para el cambio rápido de color (solo category) como para la
// edición de nombre/país (name/team) — pero hace falta al menos uno.
const PatchSchema = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  team: z.string().trim().max(120).nullable().optional(),
  category: z.enum(["amarillo", "rosa", "verde"]).optional(),
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
  if (
    !parsed.success ||
    (parsed.data.name === undefined &&
      parsed.data.team === undefined &&
      parsed.data.category === undefined)
  ) {
    return NextResponse.json({ error: "Nada que actualizar." }, { status: 400 });
  }

  const current = await sql`
    select name, team, category from special_event_riders where id = ${id}
  `;
  if (!current[0]) {
    return NextResponse.json({ error: "Corredor no encontrado." }, { status: 404 });
  }

  const name = parsed.data.name ?? (current[0].name as string);
  const team = parsed.data.team !== undefined ? parsed.data.team : (current[0].team as string | null);
  const category = (parsed.data.category ?? current[0].category) as RiderCategory;
  const multiplier = CATEGORY_MULTIPLIER[category];

  try {
    await sql`
      update special_event_riders
      set name = ${name}, team = ${team}, category = ${category}, multiplier = ${multiplier}
      where id = ${id}
    `;
  } catch {
    return NextResponse.json(
      { error: "Ya existe un corredor con ese nombre en esta prueba." },
      { status: 400 }
    );
  }

  return NextResponse.json({ ok: true, name, team, category, multiplier });
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
UKT_MUNDIAL_V3_EOF

echo "  - src/components/mundial-riders-manager.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-riders-manager.tsx" <<'UKT_MUNDIAL_V3_EOF'
"use client";

import { useMemo, useState, useTransition } from "react";
import { CATEGORY_LABEL, countryFlag, type RiderCategory } from "@/lib/mundial";

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
  const [categoryFilter, setCategoryFilter] = useState<"all" | RiderCategory>("all");
  const [name, setName] = useState("");
  const [team, setTeam] = useState("");
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [isAdding, startAdding] = useTransition();
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState("");
  const [editTeam, setEditTeam] = useState("");
  const [editError, setEditError] = useState<string | null>(null);
  const [isSavingEdit, startSavingEdit] = useTransition();

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return riders.filter((r) => {
      if (categoryFilter !== "all" && r.category !== categoryFilter) return false;
      if (!q) return true;
      return r.name.toLowerCase().includes(q) || (r.team ?? "").toLowerCase().includes(q);
    });
  }, [riders, query, categoryFilter]);

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
    if (editingId === riderId) setEditingId(null);
    const prev = riders;
    setRiders((rs) => rs.filter((r) => r.id !== riderId));
    startTransition(async () => {
      const res = await fetch(`/api/mundial/riders/${riderId}`, { method: "DELETE" });
      if (!res.ok) {
        setRiders(prev);
      }
    });
  }

  function startEdit(rider: MundialAdminRider) {
    setEditingId(rider.id);
    setEditName(rider.name);
    setEditTeam(rider.team ?? "");
    setEditError(null);
  }

  function cancelEdit() {
    setEditingId(null);
    setEditError(null);
  }

  function saveEdit(riderId: string) {
    if (!editName.trim()) return;
    setEditError(null);
    startSavingEdit(async () => {
      const res = await fetch(`/api/mundial/riders/${riderId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: editName.trim(), team: editTeam.trim() || null }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setEditError(data?.error ?? "No se pudo guardar.");
        return;
      }
      setRiders((rs) =>
        rs
          .map((r) => (r.id === riderId ? { ...r, name: data.name, team: data.team } : r))
          .sort((a, b) => a.name.localeCompare(b.name))
      );
      setEditingId(null);
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

      <div className="mt-4 flex flex-col gap-1.5">
        {filtered.map((rider) => {
          const isEditing = editingId === rider.id;
          return (
            <div
              key={rider.id}
              className="rounded-xl border border-line bg-surface px-3.5 py-2.5"
            >
              {isEditing ? (
                <div className="flex flex-col gap-2">
                  <div className="flex flex-col gap-2 sm:flex-row">
                    <input
                      type="text"
                      value={editName}
                      onChange={(e) => setEditName(e.target.value)}
                      placeholder="Nombre"
                      className="w-full rounded-full border border-line bg-[var(--bg)] px-3.5 py-2 text-sm outline-none focus:border-verde"
                    />
                    <input
                      type="text"
                      value={editTeam}
                      onChange={(e) => setEditTeam(e.target.value)}
                      placeholder="País / equipo"
                      className="w-full rounded-full border border-line bg-[var(--bg)] px-3.5 py-2 text-sm outline-none focus:border-verde sm:max-w-[220px]"
                    />
                  </div>
                  {editError && <p className="text-xs text-rosa">{editError}</p>}
                  <div className="flex gap-2">
                    <button
                      type="button"
                      disabled={isSavingEdit || !editName.trim()}
                      onClick={() => saveEdit(rider.id)}
                      className="rounded-full bg-amarillo px-3.5 py-1.5 font-display text-xs uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
                    >
                      {isSavingEdit ? "Guardando…" : "Guardar"}
                    </button>
                    <button
                      type="button"
                      onClick={cancelEdit}
                      className="rounded-full border border-line px-3.5 py-1.5 font-display text-xs uppercase tracking-wide text-text-soft"
                    >
                      Cancelar
                    </button>
                  </div>
                </div>
              ) : (
                <div className="flex items-center justify-between gap-3">
                  <span className="min-w-0 flex-1 truncate">
                    {countryFlag(rider.team) && (
                      <span className="mr-1.5">{countryFlag(rider.team)}</span>
                    )}
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
                      onClick={() => startEdit(rider)}
                      title="Editar nombre/país"
                      className="ml-1 h-8 w-8 rounded-full border border-line text-text-soft hover:border-verde-deep hover:text-verde-deep"
                    >
                      ✎
                    </button>
                    <button
                      type="button"
                      onClick={() => removeRider(rider.id)}
                      title="Eliminar"
                      className="h-8 w-8 rounded-full border border-line text-text-soft hover:border-rosa hover:text-rosa"
                    >
                      ×
                    </button>
                  </div>
                </div>
              )}
            </div>
          );
        })}
        {filtered.length === 0 && (
          <p className="text-sm text-text-soft">
            No hay corredores todavía. Añade el primero arriba.
          </p>
        )}
      </div>
    </div>
  );
}
UKT_MUNDIAL_V3_EOF

echo "  - src/components/mundial-squad-selector.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-squad-selector.tsx" <<'UKT_MUNDIAL_V3_EOF'
"use client";

import { useMemo, useState, useTransition } from "react";
import {
  CATEGORY_LABEL,
  countryFlag,
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
              {countryFlag(country) && <span className="mr-1.5">{countryFlag(country)}</span>}
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
UKT_MUNDIAL_V3_EOF


echo ""
echo "Archivos escritos. Creando commit..."
git add -A
git commit -m "Mundial: permite editar nombre/país de un corredor y añade banderas

Añade un botón de edición (lápiz) en /mundial/corredores para corregir el
nombre o el país de un corredor ya creado sin tener que borrarlo y
volver a crearlo (por ejemplo, Skjelmose). También añade una banderita de
país antes del nombre en la gestión de corredores y en la elección de
equipo."
git push

echo ""
echo "Listo. No hace falta ejecutar nada en Neon para este cambio."
