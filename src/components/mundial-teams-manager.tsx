"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import CountryFlag from "@/components/country-flag";

export type MundialTeamRow = {
  teamId: string;
  displayName: string;
  teamName: string;
  total: number;
  picks: { riderName: string; team: string | null; points: number }[];
};

// Solo para el admin: lista cada equipo fichado para el Mundial (uno por
// jugador, o varios si tiene más de uno) con un botón para borrar el
// fichaje de ese equipo en esta prueba. Nunca borra las clásicas de ese
// jugador -- ver la ruta de la API para el detalle.
export default function MundialTeamsManager({ teams }: { teams: MundialTeamRow[] }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  function removeTeam(teamId: string, teamName: string, displayName: string) {
    const ok = window.confirm(
      `¿Quitar el equipo "${teamName}" de ${displayName} del Mundial? Se borran sus 6 corredores fichados para esta prueba. Si ese equipo no se usa también en las clásicas, desaparecerá del todo de su selector de equipos. Esto no toca sus equipos de las clásicas.`
    );
    if (!ok) return;
    setError(null);
    setPendingId(teamId);
    startTransition(async () => {
      const res = await fetch(`/api/admin/mundial/teams/${teamId}`, { method: "DELETE" });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setError(data?.error ?? "No se pudo quitar el equipo.");
        setPendingId(null);
        return;
      }
      router.refresh();
    });
  }

  if (teams.length === 0) {
    return (
      <p className="mt-4 text-sm text-text-soft">
        Todavía no hay ningún equipo fichado para esta prueba.
      </p>
    );
  }

  return (
    <div className="mt-4 flex flex-col gap-3">
      {error && <p className="text-sm text-rosa">{error}</p>}
      {teams.map((t) => (
        <div key={t.teamId} className="rounded-2xl border border-line bg-surface p-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="min-w-0">
              <span className="font-display text-sm text-verde-deep">{t.teamName}</span>
              <div className="text-xs text-text-soft">{t.displayName}</div>
            </div>
            <div className="flex w-full flex-wrap items-center justify-end gap-2 sm:w-auto sm:shrink-0">
              <span className="shrink-0 font-display text-base text-amarillo">
                {t.total.toFixed(1)}
              </span>
              <button
                type="button"
                disabled={isPending && pendingId === t.teamId}
                onClick={() => removeTeam(t.teamId, t.teamName, t.displayName)}
                className="rounded-full border border-rosa px-3.5 py-2 font-display text-xs uppercase tracking-wide text-rosa disabled:opacity-50"
              >
                {isPending && pendingId === t.teamId ? "Quitando…" : "Quitar del Mundial"}
              </button>
            </div>
          </div>
          <div className="mt-2 flex flex-wrap gap-1.5 text-xs text-text-soft">
            {t.picks.map((p, j) => (
              <span key={j} className="rounded-full border border-line px-2.5 py-1">
                <CountryFlag team={p.team} className="mr-1" />
                {p.riderName} · {p.points.toFixed(1)}
              </span>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
