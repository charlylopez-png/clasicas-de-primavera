"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";

export default function LogoutButton() {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={() => {
        startTransition(async () => {
          await fetch("/api/auth/logout", { method: "POST" });
          router.push("/");
          router.refresh();
        });
      }}
      className="rounded-full px-3.5 py-2 text-left font-display text-xs uppercase tracking-wide text-[var(--pill-text)] hover:bg-[var(--pill-bg)] disabled:opacity-50"
    >
      Salir
    </button>
  );
}
