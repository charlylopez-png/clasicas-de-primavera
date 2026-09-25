#!/usr/bin/env bash
set -euo pipefail

# apply-mundial-teams-v12.sh — añade una pestaña "Equipos", solo para el
# admin, dentro de /mundial, con la lista de todos los equipos fichados
# para esta prueba y un botón para quitar el fichaje de cualquiera de
# ellos. Quitar un equipo desde aquí SOLO borra sus 6 corredores fichados
# para el Mundial: nunca toca el Equipo Base ni el Last Draft de las
# clásicas de ese mismo jugador, aunque use el mismo equipo en los dos
# sitios. Si ese equipo no tenía nada más (ni clásicas ni otro evento),
# también se borra el equipo en sí para no dejarlo vacío en su selector.
#
# No hace falta ninguna migración SQL para esto.
#
# Ejecuta esto DESDE LA RAÍZ del repo (donde está db/schema.sql), con el
# Codespace ya abierto.

if [ ! -f "db/schema.sql" ]; then
  echo "Error: no se encuentra db/schema.sql en el directorio actual."
  echo "Ejecuta este script desde la raíz del repo clasicas-de-primavera."
  exit 1
fi

echo "Aplicando gestión de equipos del Mundial para el admin (v12)..."

echo "  - src/app/api/admin/mundial/teams/[teamId]/route.ts"
mkdir -p "src/app/api/admin/mundial/teams/[teamId]"
cat > "src/app/api/admin/mundial/teams/[teamId]/route.ts" <<'UKT_MUNDIAL_TEAMS_V12_EOF'
import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { MUNDIAL_SLUG } from "@/lib/mundial";

// Deja al admin quitar el fichaje de un equipo para el Mundial. Como
// "teams" es la misma entidad que usan las clásicas (un jugador puede usar
// el mismo equipo en clásicas y Mundial a la vez desde la v7), esto NUNCA
// borra el equipo entero de golpe: solo quita sus corredores fichados para
// esta prueba. Si, después de eso, ese equipo no tiene ni Equipo Base ni
// Last Draft ni fichajes de ningún otro evento especial, se considera que
// era un equipo solo para el Mundial y se borra también, para no dejar un
// equipo vacío colgando en el selector del jugador.
export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ teamId: string }> }
) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const { teamId } = await params;

  const events = await sql`select id from special_events where slug = ${MUNDIAL_SLUG}`;
  const eventId = events[0]?.id;
  if (!eventId) {
    return NextResponse.json({ error: "No se encuentra el evento del Mundial." }, { status: 500 });
  }

  const deleted = await sql`
    delete from special_event_picks where event_id = ${eventId} and team_id = ${teamId}
    returning rider_id
  `;
  if (deleted.length === 0) {
    return NextResponse.json(
      { error: "Ese equipo no tiene fichajes para el Mundial." },
      { status: 404 }
    );
  }

  const remaining = await sql`
    select
      (select count(*) from team_base where team_id = ${teamId}) as base_count,
      (select count(*) from team_last_draft where team_id = ${teamId}) as draft_count,
      (select count(*) from special_event_picks where team_id = ${teamId}) as picks_count
  `;
  const { base_count, draft_count, picks_count } = remaining[0] as {
    base_count: string;
    draft_count: string;
    picks_count: string;
  };
  let teamDeleted = false;
  if (Number(base_count) === 0 && Number(draft_count) === 0 && Number(picks_count) === 0) {
    await sql`delete from teams where id = ${teamId}`;
    teamDeleted = true;
  }

  return NextResponse.json({ ok: true, teamDeleted });
}
UKT_MUNDIAL_TEAMS_V12_EOF

echo "  - src/components/mundial-teams-manager.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-teams-manager.tsx" <<'UKT_MUNDIAL_TEAMS_V12_EOF'
"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import CountryFlag from "@/components/country-flag";

export type MundialTeamRow = {
  teamId: string;
  displayName: string;
  teamName: string;
  total: number;
  picks: { riderName: string; team: string | null; points: number }[];
};

// Solo para el admin: lista cada equipo fichado para el Mundial (uno por
// jugador, o varios si tiene más de uno) con un botón para borrar el
// fichaje de ese equipo en esta prueba. Nunca borra las clásicas de ese
// jugador -- ver la ruta de la API para el detalle.
export default function MundialTeamsManager({ teams }: { teams: MundialTeamRow[] }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  function removeTeam(teamId: string, teamName: string, displayName: string) {
    const ok = window.confirm(
      `¿Quitar el equipo "${teamName}" de ${displayName} del Mundial? Se borran sus 6 corredores fichados para esta prueba. Si ese equipo no se usa también en las clásicas, desaparecerá del todo de su selector de equipos. Esto no toca sus equipos de las clásicas.`
    );
    if (!ok) return;
    setError(null);
    setPendingId(teamId);
    startTransition(async () => {
      const res = await fetch(`/api/admin/mundial/teams/${teamId}`, { method: "DELETE" });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setError(data?.error ?? "No se pudo quitar el equipo.");
        setPendingId(null);
        return;
      }
      router.refresh();
    });
  }

  if (teams.length === 0) {
    return (
      <p className="mt-4 text-sm text-text-soft">
        Todavía no hay ningún equipo fichado para esta prueba.
      </p>
    );
  }

  return (
    <div className="mt-4 flex flex-col gap-3">
      {error && <p className="text-sm text-rosa">{error}</p>}
      {teams.map((t) => (
        <div key={t.teamId} className="rounded-2xl border border-line bg-surface p-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div className="min-w-0">
              <span className="font-display text-sm text-verde-deep">{t.teamName}</span>
              <div className="text-xs text-text-soft">{t.displayName}</div>
            </div>
            <div className="flex w-full flex-wrap items-center justify-end gap-2 sm:w-auto sm:shrink-0">
              <span className="shrink-0 font-display text-base text-amarillo">
                {t.total.toFixed(1)}
              </span>
              <button
                type="button"
                disabled={isPending && pendingId === t.teamId}
                onClick={() => removeTeam(t.teamId, t.teamName, t.displayName)}
                className="rounded-full border border-rosa px-3.5 py-2 font-display text-xs uppercase tracking-wide text-rosa disabled:opacity-50"
              >
                {isPending && pendingId === t.teamId ? "Quitando…" : "Quitar del Mundial"}
              </button>
            </div>
          </div>
          <div className="mt-2 flex flex-wrap gap-1.5 text-xs text-text-soft">
            {t.picks.map((p, j) => (
              <span key={j} className="rounded-full border border-line px-2.5 py-1">
                <CountryFlag team={p.team} className="mr-1" />
                {p.riderName} · {p.points.toFixed(1)}
              </span>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
UKT_MUNDIAL_TEAMS_V12_EOF

echo "  - src/app/mundial/equipos/page.tsx"
mkdir -p "src/app/mundial/equipos"
cat > "src/app/mundial/equipos/page.tsx" <<'UKT_MUNDIAL_TEAMS_V12_EOF'
import { redirect } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getMundialEvent, pointsForPosition } from "@/lib/mundial";
import MundialTeamsManager, { type MundialTeamRow } from "@/components/mundial-teams-manager";

type SquadRow = {
  team_id: string;
  display_name: string;
  team_name: string;
};

type PickRow = {
  team_id: string;
  rider_name: string;
  team: string | null;
  multiplier: string;
  position: number | null;
};

export default async function MundialEquiposPage() {
  const session = await getSession();
  if (!session) redirect("/login");
  if (session.role !== "admin") redirect("/mundial");

  const event = await getMundialEvent();
  if (!event) {
    return (
      <p className="text-sm text-text-soft">
        Todavía no se ha configurado esta prueba especial.
      </p>
    );
  }

  // A diferencia de la Clasificación pública, aquí el admin ve siempre
  // todos los corredores fichados por cada equipo, esté abierto o cerrado
  // el plazo -- para poder gestionar bien qué equipo quitar.
  const squadRows = (await sql`
    select distinct t.id as team_id, t.name as team_name, u.display_name
    from special_event_picks p
    join teams t on t.id = p.team_id
    join users u on u.id = t.user_id
    where p.event_id = ${event.id}
    order by u.display_name
  `) as SquadRow[];

  const pickRows = (await sql`
    select
      p.team_id,
      r.name as rider_name,
      r.team,
      r.multiplier,
      res.position
    from special_event_picks p
    join special_event_riders r on r.id = p.rider_id
    left join special_event_results res
      on res.event_id = p.event_id and res.rider_id = p.rider_id
    where p.event_id = ${event.id}
  `) as PickRow[];

  const picksByTeam = new Map<string, PickRow[]>();
  for (const row of pickRows) {
    if (!picksByTeam.has(row.team_id)) picksByTeam.set(row.team_id, []);
    picksByTeam.get(row.team_id)!.push(row);
  }

  const teams: MundialTeamRow[] = squadRows
    .map((s) => {
      const picks = picksByTeam.get(s.team_id) ?? [];
      const total = picks.reduce(
        (sum, p) => sum + pointsForPosition(p.position) * Number(p.multiplier),
        0
      );
      return {
        teamId: s.team_id,
        displayName: s.display_name,
        teamName: s.team_name || "(sin nombre)",
        total,
        picks: picks.map((p) => ({
          riderName: p.rider_name,
          team: p.team,
          points: pointsForPosition(p.position) * Number(p.multiplier),
        })),
      };
    })
    .sort((a, b) => a.displayName.localeCompare(b.displayName));

  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Equipos del Mundial</h2>
      <p className="mt-1 max-w-prose text-sm text-text-soft">
        Todos los equipos fichados para esta prueba, sea cual sea el estado
        del plazo. Quitar un equipo de aquí solo borra su fichaje del
        Mundial — nunca toca sus equipos de las clásicas.
      </p>

      <MundialTeamsManager teams={teams} />
    </section>
  );
}
UKT_MUNDIAL_TEAMS_V12_EOF

echo "  - src/components/mundial-subnav.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-subnav.tsx" <<'UKT_MUNDIAL_TEAMS_V12_EOF'
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const ITEMS = [
  { href: "/mundial/eleccion", label: "Elección de equipo" },
  { href: "/mundial/equipo", label: "Mi equipo" },
  { href: "/mundial/clasificacion", label: "Clasificación" },
  { href: "/mundial/perfil", label: "Perfil y mapa" },
];

const ADMIN_ITEMS = [
  { href: "/mundial/corredores", label: "Corredores" },
  { href: "/mundial/equipos", label: "Equipos" },
  { href: "/mundial/resultados", label: "Resultados" },
];

export default function MundialSubNav({ isAdmin }: { isAdmin: boolean }) {
  const pathname = usePathname();
  const items = isAdmin ? [...ITEMS, ...ADMIN_ITEMS] : ITEMS;

  return (
    <nav className="flex flex-wrap gap-1.5">
      {items.map((item) => {
        const active = pathname === item.href;
        return (
          <Link
            key={item.href}
            href={item.href}
            className={`rounded-full px-3.5 py-2 font-display text-xs uppercase tracking-wide transition ${
              active
                ? "bg-verde-deep text-on-accent"
                : "border border-line bg-surface text-text-soft hover:border-verde-deep/50"
            }`}
          >
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
UKT_MUNDIAL_TEAMS_V12_EOF


echo ""
echo "Archivos escritos. Creando commit..."
git add -A
git commit -m "Añade gestión de equipos del Mundial para el admin

Nueva pestaña \"Equipos\" en /mundial (solo admin): lista todos los
equipos fichados para el Mundial y deja quitar el de cualquiera. Borra
solo el fichaje de esa prueba, nunca las clásicas del mismo jugador."
git push

echo ""
echo "Archivos aplicados. No hace falta ninguna migración SQL esta vez."