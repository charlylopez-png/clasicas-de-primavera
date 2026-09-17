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
    <div className="flex w-full flex-wrap justify-end gap-2 sm:w-auto sm:shrink-0">
      <button
        type="button"
        disabled={isPending}
        onClick={() => act("approve")}
        className="rounded-full bg-amarillo px-3.5 py-2 font-display text-xs uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-50"
      >
        Aprobar
      </button>
      <button
        type="button"
        disabled={isPending}
        onClick={() => act("reject")}
        className="rounded-full border border-rosa px-3.5 py-2 font-display text-xs uppercase tracking-wide text-rosa disabled:opacity-50"
      >
        Rechazar
      </button>
    </div>
  );
}
