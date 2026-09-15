"use client";

import { useTransition } from "react";

export default function ImpersonationBar({ actingAsName }: { actingAsName: string }) {
  const [isPending, startTransition] = useTransition();

  function stop() {
    startTransition(async () => {
      const res = await fetch("/api/admin/stop-impersonate", { method: "POST" });
      if (res.ok) {
        window.location.href = "/admin";
      }
    });
  }

  return (
    <div className="flex flex-wrap items-center justify-center gap-2.5 bg-amarillo px-4 py-2 text-center font-display text-[11px] uppercase tracking-wide text-on-accent">
      <span>Actuando como {actingAsName}</span>
      <button
        type="button"
        disabled={isPending}
        onClick={stop}
        className="rounded-full border border-on-accent/40 px-3 py-1 hover:bg-on-accent/10 disabled:opacity-50"
      >
        {isPending ? "Volviendo…" : "Volver a mi cuenta"}
      </button>
    </div>
  );
}
