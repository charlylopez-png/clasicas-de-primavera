import Link from "next/link";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import SquadSelector, { type SelectableRider } from "@/components/squad-selector";
import type { RiderCategory } from "@/lib/riders";

type RaceRow = {
  order_num: number;
  name: string;
};

type DraftPick = {
  order_num: number;
  name: string;
  category: RiderCategory;
};

export default async function MiEquipoPage() {
  const session = await getSession();
  if (!session) return null; // el proxy ya redirige a /login antes de llegar aquí

  const riders = (await sql`
    select id, name, team, division, category
    from riders
    order by division, team, name
  `) as SelectableRider[];

  const teamBase = (await sql`
    select rider_id from team_base where user_id = ${session.userId}
  `) as { rider_id: string }[];

  const races = (await sql`
    select order_num, name from races order by order_num
  `) as RaceRow[];

  const picks = (await sql`
    select r.order_num, ri.name, ri.category
    from team_last_draft tld
    join races r on r.id = tld.race_id
    join riders ri on ri.id = tld.rider_id
    where tld.user_id = ${session.userId}
    order by r.order_num, ri.category
  `) as DraftPick[];

  const picksByRace = new Map<number, DraftPick[]>();
  for (const p of picks) {
    if (!picksByRace.has(p.order_num)) picksByRace.set(p.order_num, []);
    picksByRace.get(p.order_num)!.push(p);
  }

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Tu plantilla
      </div>
      <h1 className="text-2xl text-verde-deep">
        Hola, {session.displayName}
      </h1>

      <section className="mt-8">
        <h2 className="font-display text-sm text-verde-deep">Equipo Base</h2>
        <p className="mt-1 text-sm text-text-soft">
          6 corredores fijos para toda la temporada: 1 Amarillo, 2 Rosas y 3
          Verdes. Si el Sanedrín todavía no ha clasificado a nadie fuera de
          Verde, espera a que lo haga antes de poder completar el equipo.
        </p>
        <div className="mt-4 rounded-2xl bg-surface p-4">
          <SquadSelector
            riders={riders}
            initialSelectedIds={teamBase.map((r) => r.rider_id)}
            saveUrl="/api/team-base"
          />
        </div>
      </section>

      <section className="mt-10 pb-6">
        <h2 className="font-display text-sm text-verde-deep">
          Fichajes por carrera
        </h2>
        <p className="mt-1 text-sm text-text-soft">
          El Last Draft se elige carrera a carrera, desde la página de cada
          una. Aquí solo ves el resumen.
        </p>
        <div className="mt-4 flex flex-col gap-2">
          {races.map((race) => {
            const racePicks = picksByRace.get(race.order_num) ?? [];
            return (
              <Link
                key={race.order_num}
                href={`/calendario/${race.order_num}`}
                className="flex items-center justify-between gap-3 rounded-xl border border-line bg-surface px-4 py-3 hover:border-verde-deep/50"
              >
                <div className="min-w-0">
                  <div className="font-display text-[11px] text-text-soft">
                    {String(race.order_num).padStart(2, "0")}
                  </div>
                  <div className="truncate text-sm font-semibold">{race.name}</div>
                </div>
                {racePicks.length === 6 ? (
                  <span className="shrink-0 rounded-full bg-verde px-2.5 py-1 text-[11px] font-semibold text-[var(--hero-text)]">
                    Fichado ✓
                  </span>
                ) : (
                  <span className="shrink-0 rounded-full border border-line px-2.5 py-1 text-[11px] text-text-soft">
                    Sin fichar
                  </span>
                )}
              </Link>
            );
          })}
        </div>
      </section>
    </div>
  );
}

