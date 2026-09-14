import Image from "next/image";
import Link from "next/link";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import MundialSquadSelector, {
  type MundialRider,
} from "@/components/mundial-squad-selector";
import { MUNDIAL_SLUG, formatEventDate } from "@/lib/mundial";

type EventRow = {
  id: string;
  name: string;
  event_date: string | null;
  picks_lock_at: string | null;
};

export default async function MundialPage() {
  const session = await getSession();
  if (!session) return null; // el proxy ya redirige a /login antes de llegar aquí

  const events = (await sql`
    select id, name, event_date, picks_lock_at
    from special_events where slug = ${MUNDIAL_SLUG}
  `) as EventRow[];
  const event = events[0];

  if (!event) {
    return (
      <div className="mx-auto max-w-3xl px-5 py-10">
        <h1 className="text-2xl text-verde-deep">Mundial de Montreal</h1>
        <p className="mt-4 text-sm text-text-soft">
          Todavía no se ha configurado esta prueba especial.
        </p>
      </div>
    );
  }

  const locked =
    Boolean(event.picks_lock_at) &&
    new Date(event.picks_lock_at as string).getTime() <= Date.now();

  const riders = (await sql`
    select id, name, team, category
    from special_event_riders
    where event_id = ${event.id}
    order by category, name
  `) as MundialRider[];

  const picks = (await sql`
    select rider_id from special_event_picks
    where event_id = ${event.id} and user_id = ${session.userId}
  `) as { rider_id: string }[];

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Prueba especial
      </div>

      <div className="flex items-center gap-4">
        <div className="h-20 w-20 shrink-0 overflow-hidden rounded-2xl border-2 border-white bg-white">
          <Image
            src="/mundial-logos/montreal-2026.png"
            alt="Mundial de Montreal 2026"
            width={80}
            height={80}
            className="h-full w-full object-cover"
          />
        </div>
        <div className="min-w-0">
          <h1 className="text-2xl text-verde-deep">{event.name}</h1>
          <div className="mt-1.5 flex items-center gap-1.5 text-[11px] text-text-soft">
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

      <p className="mt-4 max-w-prose text-sm text-text-soft">
        Carrera única, independiente de la clasificación general de las
        clásicas.
        {event.event_date && <> Se corre el {formatEventDate(event.event_date)}.</>}{" "}
        Elige 6 corredores de la lista cerrada: 1 Amarillo, 2 Rosas y 3 Verdes.
      </p>

      {event.picks_lock_at && (
        <p
          className={`mt-2 font-display text-xs uppercase tracking-wide ${
            locked ? "text-rosa" : "text-verde"
          }`}
        >
          {locked
            ? "Los fichajes están cerrados."
            : `Fichajes abiertos hasta ${formatEventDate(event.picks_lock_at)}.`}
        </p>
      )}

      <div className="mt-6 flex flex-wrap gap-2">
        <Link
          href="/mundial/clasificacion"
          className="rounded-full border border-line bg-surface px-4 py-2 font-display text-xs uppercase tracking-wide text-text-soft hover:border-verde-deep/50"
        >
          Ver clasificación
        </Link>
        {session.role === "admin" && (
          <>
            <Link
              href="/mundial/corredores"
              className="rounded-full border border-line bg-surface px-4 py-2 font-display text-xs uppercase tracking-wide text-text-soft hover:border-verde-deep/50"
            >
              Gestionar corredores
            </Link>
            <Link
              href="/mundial/resultados"
              className="rounded-full border border-line bg-surface px-4 py-2 font-display text-xs uppercase tracking-wide text-text-soft hover:border-verde-deep/50"
            >
              Cargar resultados
            </Link>
          </>
        )}
      </div>

      <div className="mt-6 rounded-2xl bg-surface p-4">
        {riders.length === 0 ? (
          <p className="text-sm text-text-soft">
            Todavía no hay lista de corredores para esta prueba.
          </p>
        ) : (
          <MundialSquadSelector
            riders={riders}
            initialSelectedIds={picks.map((p) => p.rider_id)}
            locked={locked}
          />
        )}
      </div>
    </div>
  );
}
