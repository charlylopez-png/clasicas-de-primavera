"use client";

import { useTransition } from "react";

export default function ImpersonateButton({ userId }: { userId: string }) {
  const [isPending, startTransition] = useTransition();

  function act() {
    startTransition(async () => {
      const res = await fetch("/api/admin/impersonate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId }),
      });
      if (res.ok) {
        window.location.href = "/";
      }
    });
  }

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={act}
      className="shrink-0 rounded-full border border-line px-3 py-1.5 font-display text-[11px] uppercase tracking-wide text-verde-deep hover:border-verde-deep disabled:opacity-50"
    >
      {isPending ? "Entrando…" : "Actuar como"}
    </button>
  );
}
