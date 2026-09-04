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
  amarillo: "bg-amarillo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
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
          className="ml-auto rounded-full bg-amarillo px-4 py-2.5 font-display text-sm uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
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
