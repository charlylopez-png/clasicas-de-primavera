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

// "Mi equipo" en modo edición: a diferencia de la Elección (agrupada por
// país, para explorar toda la lista), aquí se agrupa por color en bloques
// —Amarillo / Rosa / Verde— porque lo que importa aquí es ver de un
// vistazo si cada bloque cumple su cupo (1/2/3) y poder sumar o restar
// corredores de ese color sin salir de la pantalla. Esto también deja ver
// y corregir un equipo que dejó de cumplir el cupo porque, después de
// fichar, el admin recategorizó a uno de sus corredores.
export default function MundialTeamEditor({
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
  const [addingCategory, setAddingCategory] = useState<RiderCategory | null>(null);
  const [query, setQuery] = useState("");
  const [isPending, startTransition] = useTransition();
  const [feedback, setFeedback] = useState<
    { type: "ok" | "error"; text: string } | null
  >(null);

  const ridersById = useMemo(() => {
    const m = new Map<string, MundialRider>();
    for (const r of riders) m.set(r.id, r);
    return m;
  }, [riders]);

  const byCategory = useMemo(() => {
    const groups: Record<RiderCategory, MundialRider[]> = {
      amarillo: [],
      rosa: [],
      verde: [],
    };
    for (const r of riders) groups[r.category].push(r);
    for (const cat of CATEGORIES) groups[cat].sort((a, b) => a.name.localeCompare(b.name));
    return groups;
  }, [riders]);

  const counts = useMemo(() => {
    const cats = Array.from(selected)
      .map((id) => ridersById.get(id)?.category)
      .filter((c): c is RiderCategory => Boolean(c));
    return squadCounts(cats);
  }, [selected, ridersById]);

  const total = selected.size;
  const isValid =
    counts.amarillo === SQUAD_REQUIREMENTS.amarillo &&
    counts.rosa === SQUAD_REQUIREMENTS.rosa &&
    counts.verde === SQUAD_REQUIREMENTS.verde;
  const canSave = !locked && total === SQUAD_SIZE && teamName.trim().length > 0 && isValid;
  const wasInitiallyInvalid = useMemo(() => {
    const cats = initialSelectedIds
      .map((id) => ridersById.get(id)?.category)
      .filter((c): c is RiderCategory => Boolean(c));
    if (cats.length !== SQUAD_SIZE) return false;
    const c = squadCounts(cats);
    return (
      c.amarillo !== SQUAD_REQUIREMENTS.amarillo ||
      c.rosa !== SQUAD_REQUIREMENTS.rosa ||
      c.verde !== SQUAD_REQUIREMENTS.verde
    );
    // Solo se calcula una vez, con los datos con los que llegó la página.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function remove(riderId: string) {
    if (locked) return;
    setFeedback(null);
    setSelected((prev) => {
      const next = new Set(prev);
      next.delete(riderId);
      return next;
    });
  }

  function add(riderId: string) {
    if (locked) return;
    setFeedback(null);
    setSelected((prev) => new Set(prev).add(riderId));
    setAddingCategory(null);
    setQuery("");
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
      {wasInitiallyInvalid && (
        <div className="mb-4 rounded-xl border border-rosa/50 bg-rosa/10 px-3.5 py-2.5 text-xs text-rosa">
          Este equipo ya no cumple 1 Amarillo + 2 Rosas + 3 Verdes — seguramente
          porque un corredor que tenías fichado cambió de color después. Ajusta
          los bloques de abajo y pulsa Guardar.
        </div>
      )}

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
          placeholder="Nombre de tu equipo"
          className="w-full rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
        />
      )}

      <div className="mt-5 flex flex-col gap-4">
        {CATEGORIES.map((cat) => {
          const picked = byCategory[cat].filter((r) => selected.has(r.id));
          const required = SQUAD_REQUIREMENTS[cat];
          const ok = picked.length === required;
          const available = byCategory[cat].filter((r) => !selected.has(r.id));
          const isAdding = addingCategory === cat;
          const filteredAvailable = available.filter((r) => {
            const q = query.trim().toLowerCase();
            if (!q) return true;
            return r.name.toLowerCase().includes(q) || (r.team ?? "").toLowerCase().includes(q);
          });

          return (
            <div key={cat} className="rounded-2xl border border-line bg-surface p-3.5">
              <div className="flex items-center justify-between gap-2">
                <span
                  className={`rounded-full px-3 py-1.5 font-display text-sm uppercase tracking-wide ${
                    ok ? CATEGORY_STYLES[cat] : "border border-rosa text-rosa"
                  }`}
                >
                  {CATEGORY_LABEL[cat]} · {picked.length}/{required}
                </span>
                {!locked && !isAdding && picked.length < required && (
                  <button
                    type="button"
                    onClick={() => {
                      setAddingCategory(cat);
                      setQuery("");
                    }}
                    className="rounded-full border border-line px-3 py-1 text-xs text-verde-deep hover:border-verde-deep"
                  >
                    + Añadir
                  </button>
                )}
              </div>

              <div className="mt-2.5 flex flex-col gap-1.5">
                {picked.map((rider) => (
                  <div
                    key={rider.id}
                    className="flex items-center justify-between gap-3 rounded-xl border border-line bg-[var(--bg)] px-3.5 py-2.5"
                  >
                    <span className="min-w-0 flex-1 truncate">
                      <CountryFlag team={rider.team} className="mr-1.5" />
                      <span className="truncate text-base">{rider.name}</span>
                      {rider.team && (
                        <span className="ml-2 text-xs text-text-soft">{rider.team}</span>
                      )}
                    </span>
                    {!locked && (
                      <button
                        type="button"
                        onClick={() => remove(rider.id)}
                        title="Quitar"
                        className="h-7 w-7 shrink-0 rounded-full border border-line text-text-soft hover:border-rosa hover:text-rosa"
                      >
                        −
                      </button>
                    )}
                  </div>
                ))}
                {picked.length === 0 && (
                  <p className="text-xs text-text-faint">Ningún corredor {CATEGORY_LABEL[cat].toLowerCase()} fichado.</p>
                )}
              </div>

              {isAdding && (
                <div className="mt-3 rounded-xl border border-line bg-[var(--bg)] p-2.5">
                  <input
                    type="search"
                    autoFocus
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder={`Buscar corredor o país ${CATEGORY_LABEL[cat].toLowerCase()}…`}
                    className="w-full rounded-full border border-line bg-surface px-3.5 py-2 text-sm outline-none focus:border-verde"
                  />
                  <div className="mt-2 flex max-h-52 flex-col gap-1 overflow-y-auto">
                    {filteredAvailable.slice(0, 60).map((rider) => (
                      <button
                        key={rider.id}
                        type="button"
                        onClick={() => add(rider.id)}
                        className="flex items-center gap-2 rounded-lg px-2.5 py-1.5 text-left text-sm hover:bg-surface-2"
                      >
                        <CountryFlag team={rider.team} />
                        <span className="truncate">{rider.name}</span>
                        {rider.team && (
                          <span className="ml-auto shrink-0 text-xs text-text-soft">{rider.team}</span>
                        )}
                      </button>
                    ))}
                    {filteredAvailable.length === 0 && (
                      <p className="px-2.5 py-1.5 text-xs text-text-soft">Sin resultados.</p>
                    )}
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setAddingCategory(null);
                      setQuery("");
                    }}
                    className="mt-2 text-xs text-text-soft underline underline-offset-2"
                  >
                    Cancelar
                  </button>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {!locked && (
        <button
          type="button"
          disabled={!canSave || isPending}
          onClick={save}
          className="mt-4 w-full rounded-full bg-amarillo px-4 py-2.5 font-display text-sm uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
        >
          {isPending ? "Guardando…" : `Guardar (${total}/${SQUAD_SIZE})`}
        </button>
      )}
      {feedback && (
        <p className={`mt-2 text-sm ${feedback.type === "ok" ? "text-verde-deep" : "text-rosa"}`}>
          {feedback.text}
        </p>
      )}
    </div>
  );
}
