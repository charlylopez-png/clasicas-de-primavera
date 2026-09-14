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
