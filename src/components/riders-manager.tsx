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
  amarillo: "bg-amarillo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
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
