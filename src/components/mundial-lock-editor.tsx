"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { formatEventDate } from "@/lib/mundial";

function toLocalInputValue(value: string | Date): string {
  const d = value instanceof Date ? value : new Date(value);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(
    d.getHours()
  )}:${pad(d.getMinutes())}`;
}

// Solo para el admin: deja cambiar (o quitar) el momento de cierre de
// fichajes del Mundial desde la propia app, en la hora del dispositivo
// desde el que se edite (pensado para usarse desde España).
export default function MundialLockEditor({
  picksLockAt,
}: {
  picksLockAt: string | Date | null;
}) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(() =>
    picksLockAt ? toLocalInputValue(picksLockAt) : ""
  );
  const [error, setError] = useState<string | null>(null);

  function save(newValue: string | null) {
    setError(null);
    startTransition(async () => {
      const res = await fetch("/api/admin/mundial/lock", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ picksLockAt: newValue }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setError(data?.error ?? "No se pudo guardar.");
        return;
      }
      setEditing(false);
      router.refresh();
    });
  }

  if (!editing) {
    return (
      <div className="mt-2 flex flex-wrap items-center gap-2">
        <p className="text-xs text-text-soft">
          {picksLockAt
            ? `Cierre configurado: ${formatEventDate(picksLockAt)}.`
            : "Sin fecha de cierre configurada — los fichajes no se bloquean nunca."}
        </p>
        <button
          type="button"
          onClick={() => {
            setValue(picksLockAt ? toLocalInputValue(picksLockAt) : "");
            setEditing(true);
          }}
          className="rounded-full border border-dashed border-line px-3 py-1.5 text-xs text-verde-deep hover:border-verde-deep"
        >
          Cambiar día de cierre
        </button>
      </div>
    );
  }

  return (
    <div className="mt-2 flex flex-col items-start gap-2 rounded-xl border border-line bg-surface p-3">
      <label className="text-xs text-text-soft">
        Fichajes cerrados a partir de (hora de este dispositivo):
      </label>
      <div className="flex w-full flex-wrap items-center gap-2">
        <input
          type="datetime-local"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          className="min-w-0 flex-1 rounded-full border border-line bg-surface px-3 py-2 text-sm outline-none focus:border-verde"
        />
        <button
          type="button"
          disabled={!value || isPending}
          onClick={() => save(value)}
          className="rounded-full bg-amarillo px-3.5 py-2 text-sm font-semibold text-on-accent disabled:opacity-40"
        >
          {isPending ? "Guardando…" : "Guardar"}
        </button>
        <button
          type="button"
          disabled={isPending}
          onClick={() => setEditing(false)}
          className="rounded-full px-2.5 py-2 text-sm text-text-soft underline underline-offset-2"
        >
          Cancelar
        </button>
      </div>
      <button
        type="button"
        disabled={isPending}
        onClick={() => save(null)}
        className="text-xs text-rosa underline underline-offset-2"
      >
        Quitar cierre (dejar fichajes siempre abiertos)
      </button>
      {error && <p className="text-xs text-rosa">{error}</p>}
    </div>
  );
}
