"use client";

import { useMemo, useState, useTransition } from "react";
import {
  CATEGORY_LABEL,
  SQUAD_REQUIREMENTS,
  SQUAD_SIZE,
  squadCounts,
  type RiderCategory,
} from "@/lib/mundial";
import CountryFlag from "./country-flag";

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
            className={`rounded-full px-3 py-1.5 font-display text-sm uppercase tracking-wide ${
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
              <CountryFlag team={country} className="mr-1.5" />
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
