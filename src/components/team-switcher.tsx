"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

export type TeamOption = { id: string; name: string };

// Selector de equipo: aparece en Equipo Base, Last Draft y Mundial para
// que un jugador con más de un equipo pueda cambiar de cuál está
// editando, y crear equipos nuevos sin límite.
export default function TeamSwitcher({
  teams,
  activeTeamId,
}: {
  teams: TeamOption[];
  activeTeamId: string;
}) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState("");
  const [error, setError] = useState<string | null>(null);

  function switchTo(teamId: string) {
    if (teamId === activeTeamId || isPending) return;
    setError(null);
    startTransition(async () => {
      const res = await fetch("/api/teams/switch", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ teamId }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => null);
        setError(data?.error ?? "No se pudo cambiar de equipo.");
        return;
      }
      router.refresh();
    });
  }

  function createTeam() {
    const name = newName.trim();
    if (!name || isPending) return;
    setError(null);
    startTransition(async () => {
      const res = await fetch("/api/teams", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setError(data?.error ?? "No se pudo crear el equipo.");
        return;
      }
      setCreating(false);
      setNewName("");
      router.refresh();
    });
  }

  return (
    <div className="mb-4">
      {teams.length > 1 && (
        <p className="mb-1.5 text-[11px] text-text-soft">
          Tienes {teams.length} equipos — este cambio afecta solo al que
          tengas abierto ahora.
        </p>
      )}
      <div className="flex flex-wrap items-center gap-1.5">
        {teams.map((team) => (
          <button
            key={team.id}
            type="button"
            disabled={isPending}
            onClick={() => switchTo(team.id)}
            aria-pressed={team.id === activeTeamId}
            className={`rounded-full px-3.5 py-2 text-sm font-semibold transition disabled:opacity-50 ${
              team.id === activeTeamId
                ? "bg-verde-deep text-on-accent"
                : "border border-line bg-surface text-text-soft hover:border-verde-deep/50"
            }`}
          >
            {team.name}
          </button>
        ))}

        {creating ? (
          <div className="flex w-full flex-wrap items-center gap-1.5">
            <input
              type="text"
              autoFocus
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") createTeam();
                if (e.key === "Escape") {
                  setCreating(false);
                  setNewName("");
                }
              }}
              maxLength={60}
              placeholder="Nombre del equipo nuevo"
              className="min-w-0 flex-1 rounded-full border border-line bg-surface px-3 py-2 text-sm outline-none focus:border-verde"
            />
            <button
              type="button"
              disabled={!newName.trim() || isPending}
              onClick={createTeam}
              className="rounded-full bg-amarillo px-3.5 py-2 text-sm font-semibold text-on-accent disabled:opacity-40"
            >
              Crear
            </button>
            <button
              type="button"
              onClick={() => {
                setCreating(false);
                setNewName("");
              }}
              className="rounded-full px-2.5 py-2 text-sm text-text-soft underline underline-offset-2"
            >
              Cancelar
            </button>
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setCreating(true)}
            className="rounded-full border border-dashed border-line px-3.5 py-2 text-sm text-verde-deep hover:border-verde-deep"
          >
            + Nuevo equipo
          </button>
        )}
      </div>
      {error && <p className="mt-1.5 text-xs text-rosa">{error}</p>}
    </div>
  );
}
