import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { formatCoefficient, formatRaceDate } from "@/lib/riders";
import SquadSelector, { type SelectableRider } from "@/components/squad-selector";

type Race = {
  id: string;
  order_num: number;
  name: string;
  stars: number;
  multiplier: string | number;
  logo_path: string;
  race_date: string | Date | null;
  official_url: string | null;
};

type HistoryRow = {
  position: number;
  rider_name: string;
  team: string | null;
};

const DARK_TILE_ORDERS = new Set([9]);
const HISTORY_YEAR = 2026;

export default async function RaceDetailPage({
  params,
}: {
  params: Promise<{ order: string }>;
}) {
  const { order } = await params;
  const orderNum = Number(order);
  if (!Number.isInteger(orderNum)) notFound();

  const races = (await sql`
    select id, order_num, name, stars, multiplier, logo_path, race_date, official_url
    from races
    where order_num = ${orderNum}
  `) as Race[];
  const race = races[0];
  if (!race) notFound();

  const history = (await sql`
    select position, rider_name, team
    from race_results_history
    where race_id = ${race.id} and edition_year = ${HISTORY_YEAR}
    order by position
  `) as HistoryRow[];

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
            <span className="rounded-full bg-rosa px-2.5 py-1 font-display text-[11px] font-semibold text-on-accent">
              {formatCoefficient(race.multiplier)}
            </span>
          </div>
        </div>
      </div>

      <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-text-soft">
        <span>{race.race_date ? formatRaceDate(race.race_date) : "Fecha por confirmar."}</span>
        {race.official_url && (
          <a
            href={race.official_url}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-verde-deep underline underline-offset-2"
          >
            Web oficial ↗
          </a>
        )}
      </div>

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

      {history.length > 0 && (
        <section className="mt-8">
          <h2 className="font-display text-sm text-verde-deep">
            Edición {HISTORY_YEAR}
          </h2>
          <p className="mt-1 text-sm text-text-soft">
            {history[0] && (
              <>
                Ganador: <b className="text-verde-deep">{history[0].rider_name}</b>
                {history[0].team ? ` (${history[0].team})` : ""}.
              </>
            )}
          </p>
          <div className="mt-3 overflow-hidden rounded-2xl border border-line bg-surface">
            <ol className="divide-y divide-line">
              {history.map((row) => (
                <li
                  key={row.position}
                  className={`flex items-center gap-3 px-4 py-2 text-sm ${
                    row.position === 1 ? "bg-amarillo/20" : ""
                  }`}
                >
                  <span
                    className={`w-6 shrink-0 text-right font-display text-xs ${
                      row.position === 1 ? "text-amarillo" : "text-text-soft"
                    }`}
                  >
                    {row.position}
                  </span>
                  <span className="min-w-0 flex-1 truncate">
                    {row.rider_name}
                    {row.position === 1 && " 🏆"}
                  </span>
                  {row.team && (
                    <span className="shrink-0 truncate text-xs text-text-soft">
                      {row.team}
                    </span>
                  )}
                </li>
              ))}
            </ol>
          </div>
          {history.length < 20 && (
            <p className="mt-2 text-[11px] text-text-soft">
              De momento solo hay {history.length} posiciones confirmadas de esta
              edición.
            </p>
          )}
        </section>
      )}

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
