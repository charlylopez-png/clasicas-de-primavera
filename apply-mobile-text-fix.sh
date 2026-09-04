#!/usr/bin/env bash
set -e

if [ ! -f db/schema.sql ]; then
  echo "ERROR: no encuentro db/schema.sql en esta carpeta."
  echo "Asegurate de estar en la raiz del repo clasicas-de-primavera antes de ejecutar este script."
  exit 1
fi

mkdir -p src/components

cat > "src/components/riders-manager.tsx" << 'EOF'
"use client";

import { useMemo, useState, useTransition } from "react";
import { CATEGORY_LABEL, CATEGORY_MULTIPLIER, type RiderCategory } from "@/lib/riders";

export type Rider = {
  id: string;
  name: string;
  team: string | null;
  division: "worldtour" | "proteam" | null;
  category: RiderCategory;
  multiplier: number;
};

const CATEGORIES: RiderCategory[] = ["amarillo", "rosa", "verde"];

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-[#372802]",
  rosa: "bg-rosa text-white",
  verde: "bg-verde text-[var(--hero-text)]",
};

export default function RidersManager({ initialRiders }: { initialRiders: Rider[] }) {
  const [riders, setRiders] = useState(initialRiders);
  const [query, setQuery] = useState("");
  const [division, setDivision] = useState<"all" | "worldtour" | "proteam">("all");
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

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
    const byTeam = new Map<string, Rider[]>();
    for (const r of filtered) {
      const key = r.team ?? "Sin equipo";
      if (!byTeam.has(key)) byTeam.set(key, []);
      byTeam.get(key)!.push(r);
    }
    return Array.from(byTeam.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [filtered]);

  const counts = useMemo(() => {
    const c = { amarillo: 0, rosa: 0, verde: 0 };
    for (const r of riders) c[r.category]++;
    return c;
  }, [riders]);

  function setCategory(riderId: string, category: RiderCategory) {
    const prev = riders;
    setPendingId(riderId);
    setRiders((rs) =>
      rs.map((r) =>
        r.id === riderId ? { ...r, category, multiplier: CATEGORY_MULTIPLIER[category] } : r
      )
    );
    startTransition(async () => {
      const res = await fetch(`/api/riders/${riderId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ category }),
      });
      if (!res.ok) {
        // revierte si el servidor rechazó el cambio
        setRiders(prev);
      }
      setPendingId(null);
    });
  }

  return (
    <div className="mt-6">
      <div className="flex flex-wrap gap-2 text-xs">
        {CATEGORIES.map((c) => (
          <span
            key={c}
            className={`rounded-full px-3 py-1.5 font-display uppercase tracking-wide ${CATEGORY_STYLES[c]}`}
          >
            {CATEGORY_LABEL[c]} · {counts[c]}
          </span>
        ))}
      </div>

      <div className="mt-4 flex flex-col gap-2 sm:flex-row">
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Buscar corredor o equipo…"
          className="w-full rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
        />
        <select
          value={division}
          onChange={(e) => setDivision(e.target.value as typeof division)}
          className="rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
        >
          <option value="all">Todas las divisiones</option>
          <option value="worldtour">World Tour</option>
          <option value="proteam">ProTeam</option>
        </select>
      </div>

      <div className="mt-5 flex flex-col gap-5">
        {groups.map(([team, teamRiders]) => (
          <div key={team}>
            <h3 className="font-display text-sm uppercase tracking-wide text-verde-deep">
              {team}
            </h3>
            <div className="mt-2 flex flex-col gap-1.5">
              {teamRiders.map((rider) => (
                <div
                  key={rider.id}
                  className="flex items-center justify-between gap-3 rounded-xl border border-line bg-surface px-3.5 py-2.5"
                >
                  <span className="min-w-0 truncate text-base">{rider.name}</span>
                  <div className="flex shrink-0 gap-1.5">
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
                  </div>
                </div>
              ))}
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
  const [categoryFilter, setCategoryFilter] = useState<"all" | RiderCategory>("all");
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
      if (categoryFilter !== "all" && r.category !== categoryFilter) return false;
      if (!q) return true;
      return (
        r.name.toLowerCase().includes(q) || (r.team ?? "").toLowerCase().includes(q)
      );
    });
  }, [riders, query, division, categoryFilter]);

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
            className={`rounded-full px-3 py-1.5 font-display text-xs uppercase tracking-wide ${
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
          className="ml-auto rounded-full bg-verde-deep px-4 py-2.5 font-display text-sm uppercase tracking-wide text-white disabled:opacity-40"
        >
          {isPending ? "Guardando…" : `Guardar (${total}/${SQUAD_SIZE})`}
        </button>
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

      <div className="mt-4 flex flex-col gap-2 sm:flex-row">
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Buscar corredor o equipo…"
          className="w-full rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
        />
        <select
          value={division}
          onChange={(e) => setDivision(e.target.value as typeof division)}
          className="rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
        >
          <option value="all">Todas las divisiones</option>
          <option value="worldtour">World Tour</option>
          <option value="proteam">ProTeam</option>
        </select>
      </div>

      <div className="mt-3 flex flex-wrap items-center gap-2">
        <span className="text-xs text-text-soft">Color:</span>
        <button
          type="button"
          onClick={() => setCategoryFilter("all")}
          className={`rounded-full border px-3 py-1.5 font-display text-xs uppercase tracking-wide ${
            categoryFilter === "all"
              ? "border-verde-deep bg-verde-deep text-white"
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

      <div className="mt-5 flex flex-col gap-5">
        {groups.map(([team, teamRiders]) => (
          <div key={team}>
            <h3 className="font-display text-sm uppercase tracking-wide text-verde-deep">
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
                    className={`flex items-center justify-between gap-3 rounded-xl border px-3.5 py-2.5 text-left transition ${
                      isSelected
                        ? "border-verde-deep bg-verde-deep/10"
                        : full
                        ? "border-line bg-surface opacity-40"
                        : "border-line bg-surface hover:border-verde-deep/50"
                    }`}
                  >
                    <span className="min-w-0 truncate text-base">{rider.name}</span>
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
EOF

git add -A
git commit -m "Aumenta el tamano de fuente y ajusta espaciados en las listas de corredores

Los nombres de corredores, cabeceras de equipo y controles de categoria
se veian demasiado pequenos en movil, con mucho espacio vacio sin
aprovechar. Se aumenta el tamano de texto (nombres a text-base, chips
de categoria a text-xs, cabeceras de equipo a text-sm) y se ajusta el
padding de las filas y el tamano de los botones de categoria para
aprovechar mejor el espacio disponible. Afecta a /corredores (Sanedrin)
y a /mi-equipo y las paginas de carrera (Equipo Base / Last Draft).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016LatMv4fA2uvbQTCSnJG6u"
git push
