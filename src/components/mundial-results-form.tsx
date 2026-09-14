"use client";

import { useState, useTransition } from "react";

export type ResultsRider = {
  id: string;
  name: string;
  team: string | null;
  position: number | null;
};

export default function MundialResultsForm({
  initialRiders,
}: {
  initialRiders: ResultsRider[];
}) {
  const [positions, setPositions] = useState<Record<string, string>>(() =>
    Object.fromEntries(
      initialRiders.map((r) => [r.id, r.position ? String(r.position) : ""])
    )
  );
  const [isPending, startTransition] = useTransition();
  const [feedback, setFeedback] = useState<
    { type: "ok" | "error"; text: string } | null
  >(null);

  function save() {
    setFeedback(null);
    const results = initialRiders.map((r) => {
      const raw = positions[r.id]?.trim();
      const position = raw ? Number(raw) : null;
      return {
        riderId: r.id,
        position: position && Number.isFinite(position) ? position : null,
      };
    });
    startTransition(async () => {
      const res = await fetch("/api/mundial/results", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ results }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setFeedback({ type: "error", text: data?.error ?? "No se pudo guardar." });
        return;
      }
      setFeedback({ type: "ok", text: "Resultados guardados." });
    });
  }

  return (
    <div className="mt-6">
      <div className="flex flex-col gap-1.5">
        {initialRiders.map((r) => (
          <div
            key={r.id}
            className="flex items-center justify-between gap-3 rounded-xl border border-line bg-surface px-3.5 py-2.5"
          >
            <span className="min-w-0 flex-1 truncate">
              <span className="truncate text-base">{r.name}</span>
              {r.team && <span className="ml-2 text-xs text-text-soft">{r.team}</span>}
            </span>
            <input
              type="number"
              min={1}
              max={20}
              value={positions[r.id] ?? ""}
              onChange={(e) =>
                setPositions((prev) => ({ ...prev, [r.id]: e.target.value }))
              }
              placeholder="Puesto"
              className="w-20 shrink-0 rounded-full border border-line bg-[var(--bg)] px-3 py-1.5 text-center text-sm outline-none focus:border-verde"
            />
          </div>
        ))}
        {initialRiders.length === 0 && (
          <p className="text-sm text-text-soft">Todavía no hay corredores en la lista.</p>
        )}
      </div>

      {initialRiders.length > 0 && (
        <button
          type="button"
          disabled={isPending}
          onClick={save}
          className="mt-4 rounded-full bg-amarillo px-4 py-2.5 font-display text-sm uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
        >
          {isPending ? "Guardando…" : "Guardar resultados"}
        </button>
      )}

      {feedback && (
        <p
          className={`mt-2 text-sm ${
            feedback.type === "ok" ? "text-verde-deep" : "text-rosa"
          }`}
        >
          {feedback.text}
        </p>
      )}
    </div>
  );
}
