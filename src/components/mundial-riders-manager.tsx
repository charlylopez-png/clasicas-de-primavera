"use client";

import { useMemo, useState, useTransition } from "react";
import { CATEGORY_LABEL, type RiderCategory } from "@/lib/mundial";
import CountryFlag from "./country-flag";

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
        <a
          href="/api/mundial/riders/export"
          className="rounded-full border border-line px-3 py-1.5 text-verde-deep hover:border-verde-deep"
        >
          ⬇ Descargar listado (CSV)
        </a>
      </div>
      <p className="mt-1.5 text-[11px] text-text-faint">
        El CSV trae país y categoría de cada corredor; en Excel/Sheets puedes
        reordenarlo por la columna que quieras.
      </p>

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
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <span className="min-w-0 flex-1 truncate">
                    <CountryFlag team={rider.team} className="mr-1.5" />
                    <span className="truncate text-base">{rider.name}</span>
                    {rider.team && (
                      <span className="ml-2 text-xs text-text-soft">{rider.team}</span>
                    )}
                  </span>
                  <div className="flex w-full flex-wrap items-center justify-end gap-2 sm:w-auto sm:shrink-0">
                    {CATEGORIES.map((c) => (
                      <button
                        key={c}
                        type="button"
                        disabled={isPending && pendingId === rider.id}
                        onClick={() => setCategory(rider.id, c)}
                        aria-pressed={rider.category === c}
                        title={CATEGORY_LABEL[c]}
                        className={`h-9 w-9 rounded-full border-2 transition ${
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
                      className="ml-1 h-9 w-9 rounded-full border border-line text-text-soft hover:border-verde-deep hover:text-verde-deep"
                    >
                      ✎
                    </button>
                    <button
                      type="button"
                      onClick={() => removeRider(rider.id)}
                      title="Eliminar"
                      className="h-9 w-9 rounded-full border border-line text-text-soft hover:border-rosa hover:text-rosa"
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
