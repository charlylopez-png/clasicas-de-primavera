import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { formatCoefficient } from "@/lib/riders";
import SquadSelector, { type SelectableRider } from "@/components/squad-selector";

type Race = {
  id: string;
  order_num: number;
  name: string;
  stars: number;
  multiplier: string | number;
  logo_path: string;
  race_date: string | null;
};

const DARK_TILE_ORDERS = new Set([9]);

export default async function RaceDetailPage({
  params,
}: {
  params: Promise<{ order: string }>;
}) {
  const { order } = await params;
  const orderNum = Number(order);
  if (!Number.isInteger(orderNum)) notFound();

  const races = (await sql`
    select id, order_num, name, stars, multiplier, logo_path, race_date
    from races
    where order_num = ${orderNum}
  `) as Race[];
  const race = races[0];
  if (!race) notFound();

  const session = await getSession();
  const canDraft = Boolean(session && (session.role === "admin" || session.status === "approved"));

  let riders: SelectableRider[] = [];
  let initialSelectedIds: string[] = [];
  if (canDraft && session) {
    riders = (await sql`
      select id, name, team, division, category
      from riders
      order by division, team, name
    `) as SelectableRider[];
    const picks = (await sql`
      select rider_id from team_last_draft
      where user_id = ${session.userId} and race_id = ${race.id}
    `) as { rider_id: string }[];
    initialSelectedIds = picks.map((p) => p.rider_id);
  }

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <Link href="/calendario" className="text-xs text-text-soft hover:text-verde-deep">
        ← Calendario
      </Link>

      <div className="mt-3 flex items-center gap-4">
        <div
          className={`h-20 w-20 shrink-0 overflow-hidden rounded-2xl border-2 border-white ${
            DARK_TILE_ORDERS.has(race.order_num) ? "bg-[var(--hero-bg-1)]" : "bg-white"
          }`}
        >
          <Image
            src={race.logo_path}
            alt={race.name}
            width={80}
            height={80}
            className="h-full w-full object-cover"
          />
        </div>
        <div className="min-w-0">
          <div className="font-display text-[11px] text-text-soft">
            Carrera {String(race.order_num).padStart(2, "0")} de 12
          </div>
          <h1 className="text-2xl text-verde-deep">{race.name}</h1>
          <div className="mt-1 flex items-center gap-3">
            <span className="text-amarillo" aria-label={`${race.stars} estrellas`}>
              {"★".repeat(race.stars)}
              <span className="text-line">{"★".repeat(5 - race.stars)}</span>
            </span>
            <span className="rounded-full bg-rosa px-2.5 py-1 font-display text-[11px] font-semibold text-white">
              {formatCoefficient(race.multiplier)}
            </span>
          </div>
        </div>
      </div>

      <p className="mt-3 text-sm text-text-soft">
        {race.race_date
          ? new Date(race.race_date).toLocaleDateString("es-ES", {
              day: "numeric",
              month: "long",
              year: "numeric",
            })
          : "Fecha por confirmar."}
      </p>

      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        <div className="rounded-2xl border border-dashed border-line bg-surface p-4">
          <h2 className="font-display text-xs uppercase tracking-wide text-verde-deep">
            Perfil de la carrera
          </h2>
          <p className="mt-1.5 text-[13px] leading-relaxed text-text-soft">
            Pendiente de añadir (recorrido, desnivel, tipo de llegada…).
          </p>
        </div>
        <div className="rounded-2xl border border-dashed border-line bg-surface p-4">
          <h2 className="font-display text-xs uppercase tracking-wide text-verde-deep">
            Participantes
          </h2>
          <p className="mt-1.5 text-[13px] leading-relaxed text-text-soft">
            Pendiente de añadir el pelotón inscrito en esta carrera.
          </p>
        </div>
      </div>

      <section className="mt-10 pb-6">
        <h2 className="font-display text-sm text-verde-deep">
          Tu fichaje para esta carrera
        </h2>
        <p className="mt-1 text-sm text-text-soft">
          Last Draft: 1 Amarillo, 2 Rosas y 3 Verdes, solo para esta carrera.
        </p>

        {canDraft ? (
          <div className="mt-4 rounded-2xl bg-surface p-4">
            <SquadSelector
              riders={riders}
              initialSelectedIds={initialSelectedIds}
              saveUrl={`/api/races/${race.id}/draft`}
            />
          </div>
        ) : (
          <div className="mt-4 rounded-2xl border border-dashed border-line bg-surface p-6 text-center text-sm text-text-soft">
            {session ? (
              "Tu cuenta todavía no está aprobada."
            ) : (
              <>
                <Link href="/login" className="text-verde-deep underline">
                  Inicia sesión
                </Link>{" "}
                para fichar tu equipo de esta carrera.
              </>
            )}
          </div>
        )}
      </section>
    </div>
  );
}
