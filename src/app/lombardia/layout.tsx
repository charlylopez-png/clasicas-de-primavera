import type { ReactNode } from "react";
import Image from "next/image";
import { getSession } from "@/lib/auth";
import { getLombardiaEvent, formatEventDate, isPicksLocked } from "@/lib/lombardia";
import LombardiaSubNav from "@/components/lombardia-subnav";
import LombardiaLockEditor from "@/components/lombardia-lock-editor";

export default async function LombardiaLayout({ children }: { children: ReactNode }) {
  const session = await getSession();
  const event = await getLombardiaEvent();
  const locked = event ? isPicksLocked(event.picks_lock_at) : false;

  return (
    <div className="lombardia-scope">
      <div className="lombardia-stripe" />
      <div className="mx-auto max-w-3xl px-5 py-8">
        <div className="flex justify-center overflow-hidden rounded-2xl border border-line bg-white py-4">
          <Image
            src="/lombardia-logos/il-lombardia-2026.png"
            alt="Il Lombardia 2026 — 120ª edición, presented by Crédit Agricole, 10 de octubre"
            width={600}
            height={600}
            className="h-auto w-full max-w-[280px]"
            priority
          />
        </div>

        <div className="mt-4">
          <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
            <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
            Prueba especial
          </div>
          <h1 className="text-xl text-verde-deep">
            {event?.name ?? "Il Lombardia 2026"}
          </h1>
        </div>

        {event?.picks_lock_at && (
          <p
            className={`mt-3 font-display text-xs uppercase tracking-wide ${
              locked ? "text-rosa" : "text-verde"
            }`}
          >
            {locked
              ? "Los fichajes están cerrados."
              : `Fichajes abiertos hasta ${formatEventDate(event.picks_lock_at)}.`}
          </p>
        )}

        {session?.role === "admin" && (
          <LombardiaLockEditor picksLockAt={event?.picks_lock_at ?? null} />
        )}

        <div className="mt-5">
          <LombardiaSubNav isAdmin={session?.role === "admin"} />
        </div>

        <div className="mt-6 pb-10">{children}</div>
      </div>
    </div>
  );
}
