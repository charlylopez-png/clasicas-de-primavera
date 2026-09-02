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
      className="rounded-full px-3 py-1.5 font-display text-[11px] uppercase tracking-wide text-[var(--pill-text)] hover:bg-[var(--pill-bg)] disabled:opacity-50"
    >
      Salir
    </button>
  );
}
