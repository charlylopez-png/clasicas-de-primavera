import type { ReactNode } from "react";
import Image from "next/image";
import { getSession } from "@/lib/auth";
import { getMundialEvent, formatEventDate, isPicksLocked } from "@/lib/mundial";
import MundialSubNav from "@/components/mundial-subnav";
import MundialLockEditor from "@/components/mundial-lock-editor";

export default async function MundialLayout({ children }: { children: ReactNode }) {
  const session = await getSession();
  const event = await getMundialEvent();
  const locked = event ? isPicksLocked(event.picks_lock_at) : false;

  return (
    <div className="mundial-scope">
      <div className="mundial-stripe" />
      <div className="mx-auto max-w-3xl px-5 py-8">
        <div className="flex items-center gap-4">
          <div className="h-16 w-16 shrink-0 overflow-hidden rounded-2xl border-2 border-white bg-white">
            <Image
              src="/mundial-logos/montreal-2026.png"
              alt="Mundial de Montreal 2026"
              width={64}
              height={64}
              className="h-full w-full object-cover"
            />
          </div>
          <div className="min-w-0">
            <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
              <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
              Prueba especial
            </div>
            <h1 className="text-xl text-verde-deep">
              {event?.name ?? "Mundial de Montreal 2026"}
            </h1>
            <div className="mt-1 flex items-center gap-1.5 text-[11px] text-text-soft">
              <span>Organiza</span>
              <Image
                src="/mundial-logos/uci.png"
                alt="UCI"
                width={54}
                height={24}
                className="h-4 w-auto rounded-sm bg-white px-1 py-0.5"
              />
            </div>
          </div>
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
          <MundialLockEditor picksLockAt={event?.picks_lock_at ?? null} />
        )}

        <div className="mt-5">
          <MundialSubNav isAdmin={session?.role === "admin"} />
        </div>

        <div className="mt-6 pb-10">{children}</div>
      </div>
    </div>
  );
}
