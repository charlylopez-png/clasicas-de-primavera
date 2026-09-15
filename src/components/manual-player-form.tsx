"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

export default function ManualPlayerForm() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  function add(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    setError(null);
    startTransition(async () => {
      const res = await fetch("/api/admin/manual-players", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ displayName: name.trim() }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setError(data?.error ?? "No se pudo añadir el jugador.");
        return;
      }
      setName("");
      router.refresh();
    });
  }

  return (
    <form onSubmit={add} className="flex flex-col gap-2 rounded-xl bg-surface p-3 sm:flex-row">
      <input
        type="text"
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder="Nombre del jugador (sin cuenta propia)"
        className="w-full rounded-full border border-line bg-[var(--bg)] px-4 py-2 text-sm outline-none focus:border-verde"
      />
      <button
        type="submit"
        disabled={isPending || !name.trim()}
        className="shrink-0 rounded-full bg-amarillo px-4 py-2 font-display text-xs uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
      >
        {isPending ? "Añadiendo…" : "+ Añadir"}
      </button>
      {error && <p className="text-xs text-rosa sm:self-center">{error}</p>}
    </form>
  );
}
