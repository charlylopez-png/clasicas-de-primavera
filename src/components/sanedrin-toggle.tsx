"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

export default function SanedrinToggle({
  userId,
  isSanedrin,
  disabled,
}: {
  userId: string;
  isSanedrin: boolean;
  disabled?: boolean;
}) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function toggle() {
    setError(null);
    startTransition(async () => {
      const res = await fetch(`/api/admin/users/${userId}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: isSanedrin ? "sanedrin_off" : "sanedrin_on" }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => null);
        setError(data?.error ?? "No se pudo actualizar.");
        return;
      }
      router.refresh();
    });
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <button
        type="button"
        disabled={isPending || (disabled && !isSanedrin)}
        onClick={toggle}
        className={`shrink-0 rounded-full px-3 py-1.5 font-display text-[11px] uppercase tracking-wide disabled:opacity-50 ${
          isSanedrin
            ? "bg-verde-deep text-white"
            : "border border-verde-deep text-verde-deep"
        }`}
      >
        {isSanedrin ? "Sanedrín ✓" : "Sanedrín"}
      </button>
      {error && <span className="max-w-[10rem] text-right text-[10px] text-rosa">{error}</span>}
    </div>
  );
}
