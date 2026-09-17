"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";

export default function DeleteManualPlayerButton({ userId }: { userId: string }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  function remove() {
    if (!window.confirm("¿Quitar a este jugador manual? Se borra también su equipo/ficha.")) {
      return;
    }
    startTransition(async () => {
      const res = await fetch(`/api/admin/manual-players/${userId}`, { method: "DELETE" });
      if (res.ok) router.refresh();
    });
  }

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={remove}
      title="Quitar jugador manual"
      className="h-9 w-9 shrink-0 rounded-full border border-line text-text-soft hover:border-rosa hover:text-rosa disabled:opacity-50"
    >
      ×
    </button>
  );
}
