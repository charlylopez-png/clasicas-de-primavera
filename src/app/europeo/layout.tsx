import type { ReactNode } from "react";
import Image from "next/image";
import { getSession } from "@/lib/auth";
import { getEuropeoEvent, formatEventDate, isPicksLocked } from "@/lib/europeo";
import EuropeoSubNav from "@/components/europeo-subnav";
import EuropeoLockEditor from "@/components/europeo-lock-editor";

export default async function EuropeoLayout({ children }: { children: ReactNode }) {
  const session = await getSession();
  const event = await getEuropeoEvent();
  const locked = event ? isPicksLocked(event.picks_lock_at) : false;

  return (
    <div className="europeo-scope">
      <div className="europeo-stripe" />
      <div className="mx-auto max-w-3xl px-5 py-8">
        <div className="overflow-hidden rounded-2xl border border-line">
          <Image
            src="/europeo-logos/ljubljana-2026.png"
            alt="UEC Road European Championships 2026 — Ljubljana, Eslovenia"
            width={1384}
            height={598}
            className="h-auto w-full"
            priority
          />
        </div>

        <div className="mt-4">
          <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
            <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
            Prueba especial
          </div>
          <h1 className="text-xl text-verde-deep">
            {event?.name ?? "Europeo de Ljubljana 2026"}
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
          <EuropeoLockEditor picksLockAt={event?.picks_lock_at ?? null} />
        )}

        <div className="mt-5">
          <EuropeoSubNav isAdmin={session?.role === "admin"} />
        </div>

        <div className="mt-6 pb-10">{children}</div>
      </div>
    </div>
  );
}
