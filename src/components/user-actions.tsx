"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";

export default function UserActions({ userId }: { userId: string }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  function act(action: "approve" | "reject") {
    startTransition(async () => {
      await fetch(`/api/admin/users/${userId}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action }),
      });
      router.refresh();
    });
  }

  return (
    <div className="flex shrink-0 gap-2">
      <button
        type="button"
        disabled={isPending}
        onClick={() => act("approve")}
        className="rounded-full bg-verde px-3 py-1.5 font-display text-[11px] uppercase tracking-wide text-[var(--hero-text)] disabled:opacity-50"
      >
        Aprobar
      </button>
      <button
        type="button"
        disabled={isPending}
        onClick={() => act("reject")}
        className="rounded-full border border-rosa px-3 py-1.5 font-display text-[11px] uppercase tracking-wide text-rosa disabled:opacity-50"
      >
        Rechazar
      </button>
    </div>
  );
}
