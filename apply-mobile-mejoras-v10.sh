#!/usr/bin/env bash
set -euo pipefail

# apply-mobile-mejoras-v10.sh — arregla el corte de la sección de
# administración en el móvil (los botones empujaban el nombre del
# participante fuera de la pantalla) y mejora la comodidad general de la
# app en el móvil: filas que ahora saltan de línea en vez de cortarse,
# botones más grandes para tocar con el dedo, y texto principal (contadores
# de equipo, reglamento, fichas de carrera) algo más grande y legible.
# El diseño, los colores y la distribución general de la app no cambian.
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

echo "Aplicando mejoras de vista en móvil (v10)..."

echo "  - src/app/admin/page.tsx"
mkdir -p "src/app/admin"
cat > "src/app/admin/page.tsx" <<'UKT_MOBILE_V10_EOF'
import { sql } from "@/lib/db";
import UserActions from "@/components/user-actions";
import SanedrinToggle from "@/components/sanedrin-toggle";
import ManualPlayerForm from "@/components/manual-player-form";
import DeleteManualPlayerButton from "@/components/delete-manual-player-button";
import ImpersonateButton from "@/components/impersonate-button";
import ResetPasswordButton from "@/components/reset-password-button";

type UserRow = {
  id: string;
  email: string;
  display_name: string;
  status: "pending" | "approved" | "rejected";
  role: "admin" | "participant";
  is_sanedrin: boolean;
  is_manual: boolean;
  created_at: string;
};

const SANEDRIN_LIMIT = 3;

export default async function AdminPage() {
  const users = (await sql`
    select id, email, display_name, status, role, is_sanedrin, is_manual, created_at
    from users
    order by (status = 'pending') desc, created_at desc
  `) as UserRow[];

  const pending = users.filter((u) => u.status === "pending");
  const resolved = users.filter((u) => u.status !== "pending");
  const sanedrinCount = users.filter((u) => u.is_sanedrin).length;

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Administración
      </div>
      <h1 className="text-2xl text-verde-deep">Participantes</h1>
      <p className="mt-2 text-sm text-text-soft">
        Aprueba o rechaza a quien se apunte a la porra. Solo los aprobados
        pueden elegir equipo y ver la clasificación.
      </p>

      <section className="mt-8">
        <h2 className="font-display text-sm text-verde-deep">Jugadores manuales</h2>
        <p className="mt-1 text-xs text-text-soft">
          Para gente que no va a entrar por su cuenta en la app (mayores con
          dificultades con la tecnología, por ejemplo): añádelos con solo su
          nombre, sin cuenta ni contraseña, y usa &quot;Actuar como&quot; más
          abajo para fichar por ellos en las clásicas o en el Mundial, igual
          que haría cualquier jugador.
        </p>
        <div className="mt-3">
          <ManualPlayerForm />
        </div>
      </section>

      <section className="mt-8">
        <h2 className="font-display text-sm text-verde-deep">
          Pendientes ({pending.length})
        </h2>
        {pending.length === 0 ? (
          <p className="mt-2 text-sm text-text-soft">No hay nadie esperando.</p>
        ) : (
          <div className="mt-3 flex flex-col gap-2">
            {pending.map((u) => (
              <div
                key={u.id}
                className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-line bg-surface p-3"
              >
                <div className="min-w-0">
                  <div className="truncate text-base font-semibold">{u.display_name}</div>
                  <div className="truncate text-sm text-text-soft">{u.email}</div>
                </div>
                <UserActions userId={u.id} />
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="mt-8">
        <div className="flex items-center justify-between">
          <h2 className="font-display text-sm text-verde-deep">Resto</h2>
          <span className="rounded-full bg-surface px-2.5 py-1 text-[11px] text-text-soft">
            Sanedrín: {sanedrinCount}/{SANEDRIN_LIMIT}
          </span>
        </div>
        <p className="mt-1 text-xs text-text-soft">
          El Sanedrín tiene acceso previo a la base de datos de corredores
          para clasificarlos. Como mucho {SANEDRIN_LIMIT} a la vez.
        </p>
        <div className="mt-3 flex flex-col gap-2">
          {resolved.map((u) => (
            <div
              key={u.id}
              className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-line bg-surface p-3"
            >
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="truncate text-base font-semibold">{u.display_name}</span>
                  {u.is_manual && (
                    <span className="shrink-0 rounded-full border border-line px-2 py-0.5 text-[10px] uppercase tracking-wide text-text-soft">
                      Sin cuenta
                    </span>
                  )}
                </div>
                <div className="truncate text-sm text-text-soft">
                  {u.is_manual ? "Gestionado por ti" : u.email}
                </div>
              </div>
              <div className="flex w-full flex-wrap items-center justify-end gap-2 sm:w-auto sm:shrink-0">
                <span
                  className={`shrink-0 rounded-full px-2.5 py-1 text-[11px] font-semibold ${
                    u.status === "approved"
                      ? "bg-verde text-on-accent"
                      : "bg-rosa text-on-accent"
                  }`}
                >
                  {u.status === "approved" ? "Aprobado" : "Rechazado"}
                  {u.role === "admin" ? " · Admin" : ""}
                </span>
                {u.status === "approved" && u.role !== "admin" && (
                  <>
                    <SanedrinToggle
                      userId={u.id}
                      isSanedrin={u.is_sanedrin}
                      disabled={sanedrinCount >= SANEDRIN_LIMIT}
                    />
                    <ImpersonateButton userId={u.id} />
                    {!u.is_manual && (
                      <ResetPasswordButton userId={u.id} displayName={u.display_name} />
                    )}
                  </>
                )}
                {u.is_manual && <DeleteManualPlayerButton userId={u.id} />}
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
UKT_MOBILE_V10_EOF

echo "  - src/app/reglamento/page.tsx"
mkdir -p "src/app/reglamento"
cat > "src/app/reglamento/page.tsx" <<'UKT_MOBILE_V10_EOF'
export default function ReglamentoPage() {
  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <Kicker>Las reglas, en corto</Kicker>
      <h1 className="text-2xl text-verde-deep">Cómo funciona la porra</h1>
      <p className="mt-2 max-w-prose text-sm text-text-soft">
        Tres mecanismos evitan que la liga la gane siempre &quot;el más
        obvio&quot; y mantienen la pelea viva hasta la última carrera.
      </p>

      <div className="mt-8 grid gap-4 sm:grid-cols-3">
        <RuleCard n="01" title="Coeficientes" accent="verde">
          Carreras y corredores puntúan distinto según su categoría. Un
          favorito ganando una carrera menor vale bastante menos que una
          sorpresa triunfando en un Monumento.
        </RuleCard>
        <RuleCard n="02" title="Tu equipo" accent="amarillo">
          Plantilla de 12 corredores en dos bloques: el Equipo Base, fijo
          toda la temporada, y el Last Draft, que recompones carrera a
          carrera.
        </RuleCard>
        <RuleCard n="03" title="El Sprint" accent="rosa">
          Un duelo contra otro participante en cada carrera, sorteado al
          inicio de temporada. Ganarlo suma puntos extra; perderlo, los
          resta.
        </RuleCard>
      </div>

      <div
        className="mt-8 rounded-2xl p-6 text-[var(--hero-text)]"
        style={{ background: "var(--hero-bg-1)" }}
      >
        <h2 className="font-display text-xs tracking-wide text-amarillo">
          Fórmula de puntuación de cada corredor
        </h2>
        <div className="mt-3 rounded-xl border border-dashed border-white/35 bg-white/5 p-4 text-center font-display text-base">
          Puntos por puesto <span className="text-amarillo">×</span>{" "}
          Coeficiente de la carrera <span className="text-amarillo">×</span>{" "}
          Coeficiente del corredor
        </div>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          <Example title="Favorito claro">
            Amarillo (×1) gana la Milano–Sanremo (5★, ×2): 100 × 2 × 1 ={" "}
            <b className="text-amarillo">200 pts</b>
          </Example>
          <Example title="Sorpresa premiada">
            Verde (×2) es 5º en la Ronde van Vlaanderen (5★, ×2): 16 × 2 × 2 ={" "}
            <b className="text-amarillo">64 pts</b>
          </Example>
        </div>
      </div>

      <div className="mt-10">
        <Kicker>Puntuación base</Kicker>
        <h2 className="text-xl text-verde-deep">Puntos por puesto</h2>
        <p className="mt-2 max-w-prose text-sm text-text-soft">
          Puntuación de partida antes de aplicar los coeficientes.
          Puntúan los 20 primeros.
        </p>
        <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
          {POINTS.map(([pos, pts], i) => (
            <div
              key={pos}
              className={`flex items-center justify-between rounded-lg px-3 py-2 text-sm ${
                i < 3 ? "bg-amarillo text-on-accent font-bold" : "bg-surface"
              }`}
            >
              <span>{pos}º</span>
              <b className="font-display">{pts}</b>
            </div>
          ))}
        </div>
      </div>

      <div className="mt-10">
        <Kicker>Tu plantilla</Kicker>
        <h2 className="text-xl text-verde-deep">Los corredores</h2>
        <p className="mt-2 max-w-prose text-sm text-text-soft">
          Cuanto menos favorito, más multiplica: una sorpresa bien elegida
          puede valer tanto como un ganador cantado.
        </p>
        <div className="mt-4 grid gap-4 sm:grid-cols-3">
          <CategoryCard
            name="Amarillo"
            mult="×1"
            className="bg-gradient-to-br from-[#e9c03a] to-[#c8901a] text-on-accent"
          >
            Top élite y favoritos indiscutibles (Pogačar, MVDP…). Ganan a
            menudo, pero apenas multiplican.
          </CategoryCard>
          <CategoryCard
            name="Rosa"
            mult="×1,5"
            className="bg-gradient-to-br from-[#f58fb0] to-[#d16c93] text-on-accent"
          >
            Corredores de élite, candidatos serios sin ser los favoritos
            absolutos.
          </CategoryCard>
          <CategoryCard
            name="Verde"
            mult="×2"
            className="bg-gradient-to-br from-[#3f8663] to-[#1a4c36] text-white"
          >
            El resto del pelotón. Menos probable que puntúen, pero cuando lo
            hacen, multiplican por dos.
          </CategoryCard>
        </div>

        <div className="mt-4 rounded-2xl bg-surface p-5">
          <SquadBlock title="Equipo Base" when="Fijo para toda la temporada" />
          <div className="my-3 border-t border-dashed border-line" />
          <SquadBlock title="Last Draft" when="Se recompone antes de cada carrera" />
          <div className="mt-3 border-t border-dashed border-line pt-3 text-center font-display text-xs tracking-wide text-verde-deep">
            6 + 6 = 12 CORREDORES EN TU PLANTILLA
          </div>
        </div>
      </div>

      <div className="mt-10 pb-6">
        <Kicker>La guinda</Kicker>
        <h2 className="text-xl text-verde-deep">El Sprint</h2>
        <div
          className="mt-4 rounded-2xl p-5 text-sm leading-relaxed text-white"
          style={{ background: "linear-gradient(135deg, #c53f74, #a63464)" }}
        >
          &quot;La máquina&quot; sortea al inicio de temporada un rival
          distinto para cada una de las 12 carreras. En cada una, además de
          tus puntos, se compara tu puntuación de esa jornada con la de tu
          rival de turno.
        </div>
        <div className="mt-4 flex items-center gap-3">
          <div className="flex-1 rounded-xl border-2 border-verde bg-surface py-5 text-center">
            <div className="font-display text-3xl font-bold text-verde">+100</div>
            <div className="mt-1 text-[10px] uppercase tracking-wide text-text-soft">
              Gana el Sprint
            </div>
          </div>
          <div className="font-display text-sm text-text-soft">VS</div>
          <div className="flex-1 rounded-xl border-2 border-rosa bg-surface py-5 text-center">
            <div className="font-display text-3xl font-bold text-rosa">−50</div>
            <div className="mt-1 text-[10px] uppercase tracking-wide text-text-soft">
              Pierde el Sprint
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

const POINTS: [number, number][] = [
  [1, 100], [2, 50], [3, 30], [4, 20], [5, 16], [6, 15], [7, 14], [8, 13],
  [9, 12], [10, 11], [11, 10], [12, 9], [13, 8], [14, 7], [15, 6], [16, 5],
  [17, 4], [18, 3], [19, 2], [20, 1],
];

function Kicker({ children }: { children: React.ReactNode }) {
  return (
    <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
      <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
      {children}
    </div>
  );
}

function RuleCard({
  n,
  title,
  accent,
  children,
}: {
  n: string;
  title: string;
  accent: "verde" | "amarillo" | "rosa";
  children: React.ReactNode;
}) {
  const borderColor =
    accent === "verde"
      ? "border-t-verde"
      : accent === "amarillo"
      ? "border-t-amarillo"
      : "border-t-rosa";
  return (
    <div className={`rounded-2xl border-t-4 bg-surface p-4 ${borderColor}`}>
      <div className="font-display text-[11px] text-text-soft">{n}</div>
      <h3 className="mt-1 text-base text-verde-deep">{title}</h3>
      <p className="mt-1.5 text-sm leading-relaxed text-text-soft">
        {children}
      </p>
    </div>
  );
}

function Example({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-xl bg-white/5 p-3 text-sm leading-relaxed">
      <b className="text-amarillo">{title}.</b> {children}
    </div>
  );
}

function CategoryCard({
  name,
  mult,
  className,
  children,
}: {
  name: string;
  mult: string;
  className: string;
  children: React.ReactNode;
}) {
  return (
    <div className={`rounded-2xl p-4 ${className}`}>
      <div className="flex items-baseline justify-between">
        <span className="font-display text-base font-bold">{name}</span>
        <span className="font-display text-xl font-bold">{mult}</span>
      </div>
      <p className="mt-1.5 text-sm leading-relaxed">{children}</p>
    </div>
  );
}

function SquadBlock({ title, when }: { title: string; when: string }) {
  return (
    <div>
      <h4 className="font-display text-sm text-verde-deep">{title}</h4>
      <div className="mb-2 text-[11px] text-text-soft">{when}</div>
      <div className="flex flex-wrap gap-2">
        <Tag>Amarillo ×1</Tag>
        <Tag>Rosa ×1,5</Tag>
        <Tag>Verde ×2</Tag>
      </div>
    </div>
  );
}

function Tag({ children }: { children: React.ReactNode }) {
  return (
    <span className="rounded-lg border border-line bg-bg px-2.5 py-1 text-[12px]">
      {children}
    </span>
  );
}
UKT_MOBILE_V10_EOF

echo "  - src/app/calendario/[order]/page.tsx"
mkdir -p "src/app/calendario/[order]"
cat > "src/app/calendario/[order]/page.tsx" <<'UKT_MOBILE_V10_EOF'
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getActiveTeam } from "@/lib/teams";
import { formatCoefficient, formatRaceDate } from "@/lib/riders";
import SquadSelector, { type SelectableRider } from "@/components/squad-selector";
import TeamSwitcher from "@/components/team-switcher";

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
  let teams: { id: string; name: string }[] = [];
  let activeTeamId = "";
  if (canDraft && session) {
    const active = await getActiveTeam(session.userId);
    teams = active.teams;
    activeTeamId = active.activeTeam.id;

    riders = (await sql`
      select id, name, team, division, category
      from riders
      order by division, team, name
    `) as SelectableRider[];
    const picks = (await sql`
      select rider_id from team_last_draft
      where team_id = ${activeTeamId} and race_id = ${race.id}
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
          <p className="mt-1.5 text-sm leading-relaxed text-text-soft">
            Pendiente de añadir (recorrido, desnivel, tipo de llegada…).
          </p>
        </div>
        <div className="rounded-2xl border border-dashed border-line bg-surface p-4">
          <h2 className="font-display text-xs uppercase tracking-wide text-verde-deep">
            Participantes
          </h2>
          <p className="mt-1.5 text-sm leading-relaxed text-text-soft">
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
            <TeamSwitcher teams={teams} activeTeamId={activeTeamId} />
            <SquadSelector
              key={activeTeamId}
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
UKT_MOBILE_V10_EOF

echo "  - src/components/user-actions.tsx"
mkdir -p "src/components"
cat > "src/components/user-actions.tsx" <<'UKT_MOBILE_V10_EOF'
"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";

export default function UserActions({ userId }: { userId: string }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  function act(action: "approve" | "reject") {
    startTransition(async () => {
      await fetch(`/api/admin/users/${userId}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action }),
      });
      router.refresh();
    });
  }

  return (
    <div className="flex w-full flex-wrap justify-end gap-2 sm:w-auto sm:shrink-0">
      <button
        type="button"
        disabled={isPending}
        onClick={() => act("approve")}
        className="rounded-full bg-amarillo px-3.5 py-2 font-display text-xs uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-50"
      >
        Aprobar
      </button>
      <button
        type="button"
        disabled={isPending}
        onClick={() => act("reject")}
        className="rounded-full border border-rosa px-3.5 py-2 font-display text-xs uppercase tracking-wide text-rosa disabled:opacity-50"
      >
        Rechazar
      </button>
    </div>
  );
}
UKT_MOBILE_V10_EOF

echo "  - src/components/delete-manual-player-button.tsx"
mkdir -p "src/components"
cat > "src/components/delete-manual-player-button.tsx" <<'UKT_MOBILE_V10_EOF'
"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";

export default function DeleteManualPlayerButton({ userId }: { userId: string }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  function remove() {
    if (!window.confirm("¿Quitar a este jugador manual? Se borra también su equipo/ficha.")) {
      return;
    }
    startTransition(async () => {
      const res = await fetch(`/api/admin/manual-players/${userId}`, { method: "DELETE" });
      if (res.ok) router.refresh();
    });
  }

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={remove}
      title="Quitar jugador manual"
      className="h-9 w-9 shrink-0 rounded-full border border-line text-text-soft hover:border-rosa hover:text-rosa disabled:opacity-50"
    >
      ×
    </button>
  );
}
UKT_MOBILE_V10_EOF

echo "  - src/components/riders-manager.tsx"
mkdir -p "src/components"
cat > "src/components/riders-manager.tsx" <<'UKT_MOBILE_V10_EOF'
"use client";

import { useMemo, useState, useTransition } from "react";
import { CATEGORY_LABEL, CATEGORY_MULTIPLIER, type RiderCategory } from "@/lib/riders";

export type Rider = {
  id: string;
  name: string;
  team: string | null;
  division: "worldtour" | "proteam" | null;
  category: RiderCategory;
  multiplier: number;
};

const CATEGORIES: RiderCategory[] = ["amarillo", "rosa", "verde"];

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
};

export default function RidersManager({ initialRiders }: { initialRiders: Rider[] }) {
  const [riders, setRiders] = useState(initialRiders);
  const [query, setQuery] = useState("");
  const [division, setDivision] = useState<"all" | "worldtour" | "proteam">("all");
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return riders.filter((r) => {
      if (division !== "all" && r.division !== division) return false;
      if (!q) return true;
      return (
        r.name.toLowerCase().includes(q) || (r.team ?? "").toLowerCase().includes(q)
      );
    });
  }, [riders, query, division]);

  const groups = useMemo(() => {
    const byTeam = new Map<string, Rider[]>();
    for (const r of filtered) {
      const key = r.team ?? "Sin equipo";
      if (!byTeam.has(key)) byTeam.set(key, []);
      byTeam.get(key)!.push(r);
    }
    return Array.from(byTeam.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [filtered]);

  const counts = useMemo(() => {
    const c = { amarillo: 0, rosa: 0, verde: 0 };
    for (const r of riders) c[r.category]++;
    return c;
  }, [riders]);

  function setCategory(riderId: string, category: RiderCategory) {
    const prev = riders;
    setPendingId(riderId);
    setRiders((rs) =>
      rs.map((r) =>
        r.id === riderId ? { ...r, category, multiplier: CATEGORY_MULTIPLIER[category] } : r
      )
    );
    startTransition(async () => {
      const res = await fetch(`/api/riders/${riderId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ category }),
      });
      if (!res.ok) {
        // revierte si el servidor rechazó el cambio
        setRiders(prev);
      }
      setPendingId(null);
    });
  }

  return (
    <div className="mt-6">
      <div className="flex flex-wrap gap-2 text-xs">
        {CATEGORIES.map((c) => (
          <span
            key={c}
            className={`rounded-full px-3 py-1.5 font-display uppercase tracking-wide ${CATEGORY_STYLES[c]}`}
          >
            {CATEGORY_LABEL[c]} · {counts[c]}
          </span>
        ))}
      </div>

      <div className="mt-4 flex flex-col gap-2 sm:flex-row">
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Buscar corredor o equipo…"
          className="w-full rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
        />
        <select
          value={division}
          onChange={(e) => setDivision(e.target.value as typeof division)}
          className="rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
        >
          <option value="all">Todas las divisiones</option>
          <option value="worldtour">World Tour</option>
          <option value="proteam">ProTeam</option>
        </select>
      </div>

      <div className="mt-5 flex flex-col gap-5">
        {groups.map(([team, teamRiders]) => (
          <div key={team}>
            <h3 className="font-display text-sm uppercase tracking-wide text-verde-deep">
              {team}
            </h3>
            <div className="mt-2 flex flex-col gap-1.5">
              {teamRiders.map((rider) => (
                <div
                  key={rider.id}
                  className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-line bg-surface px-3.5 py-2.5"
                >
                  <span className="min-w-0 truncate text-base">{rider.name}</span>
                  <div className="flex w-full flex-wrap justify-end gap-2 sm:w-auto sm:shrink-0">
                    {CATEGORIES.map((c) => (
                      <button
                        key={c}
                        type="button"
                        disabled={isPending && pendingId === rider.id}
                        onClick={() => setCategory(rider.id, c)}
                        aria-pressed={rider.category === c}
                        title={CATEGORY_LABEL[c]}
                        className={`h-9 w-9 rounded-full border-2 transition ${
                          rider.category === c
                            ? `${CATEGORY_STYLES[c]} border-transparent`
                            : "border-line bg-transparent opacity-40 hover:opacity-70"
                        }`}
                      />
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
        {groups.length === 0 && (
          <p className="text-sm text-text-soft">No hay corredores que coincidan.</p>
        )}
      </div>
    </div>
  );
}
UKT_MOBILE_V10_EOF

echo "  - src/components/mundial-riders-manager.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-riders-manager.tsx" <<'UKT_MOBILE_V10_EOF'
"use client";

import { useMemo, useState, useTransition } from "react";
import { CATEGORY_LABEL, type RiderCategory } from "@/lib/mundial";
import CountryFlag from "./country-flag";

export type MundialAdminRider = {
  id: string;
  name: string;
  team: string | null;
  category: RiderCategory;
  multiplier: number;
};

const CATEGORIES: RiderCategory[] = ["amarillo", "rosa", "verde"];

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
};

export default function MundialRidersManager({
  initialRiders,
}: {
  initialRiders: MundialAdminRider[];
}) {
  const [riders, setRiders] = useState(initialRiders);
  const [query, setQuery] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<"all" | RiderCategory>("all");
  const [name, setName] = useState("");
  const [team, setTeam] = useState("");
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [isAdding, startAdding] = useTransition();
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState("");
  const [editTeam, setEditTeam] = useState("");
  const [editError, setEditError] = useState<string | null>(null);
  const [isSavingEdit, startSavingEdit] = useTransition();

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return riders.filter((r) => {
      if (categoryFilter !== "all" && r.category !== categoryFilter) return false;
      if (!q) return true;
      return r.name.toLowerCase().includes(q) || (r.team ?? "").toLowerCase().includes(q);
    });
  }, [riders, query, categoryFilter]);

  const counts = useMemo(() => {
    const c = { amarillo: 0, rosa: 0, verde: 0 };
    for (const r of riders) c[r.category]++;
    return c;
  }, [riders]);

  function addRider(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    setError(null);
    startAdding(async () => {
      const res = await fetch("/api/mundial/riders", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: name.trim(), team: team.trim() || null }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setError(data?.error ?? "No se pudo añadir el corredor.");
        return;
      }
      setRiders((rs) =>
        [...rs.filter((r) => r.id !== data.rider.id), data.rider].sort((a, b) =>
          a.name.localeCompare(b.name)
        )
      );
      setName("");
      setTeam("");
    });
  }

  function setCategory(riderId: string, category: RiderCategory) {
    const prev = riders;
    setPendingId(riderId);
    setRiders((rs) => rs.map((r) => (r.id === riderId ? { ...r, category } : r)));
    startTransition(async () => {
      const res = await fetch(`/api/mundial/riders/${riderId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ category }),
      });
      if (!res.ok) {
        setRiders(prev);
      }
      setPendingId(null);
    });
  }

  function removeRider(riderId: string) {
    if (editingId === riderId) setEditingId(null);
    const prev = riders;
    setRiders((rs) => rs.filter((r) => r.id !== riderId));
    startTransition(async () => {
      const res = await fetch(`/api/mundial/riders/${riderId}`, { method: "DELETE" });
      if (!res.ok) {
        setRiders(prev);
      }
    });
  }

  function startEdit(rider: MundialAdminRider) {
    setEditingId(rider.id);
    setEditName(rider.name);
    setEditTeam(rider.team ?? "");
    setEditError(null);
  }

  function cancelEdit() {
    setEditingId(null);
    setEditError(null);
  }

  function saveEdit(riderId: string) {
    if (!editName.trim()) return;
    setEditError(null);
    startSavingEdit(async () => {
      const res = await fetch(`/api/mundial/riders/${riderId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: editName.trim(), team: editTeam.trim() || null }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setEditError(data?.error ?? "No se pudo guardar.");
        return;
      }
      setRiders((rs) =>
        rs
          .map((r) => (r.id === riderId ? { ...r, name: data.name, team: data.team } : r))
          .sort((a, b) => a.name.localeCompare(b.name))
      );
      setEditingId(null);
    });
  }

  return (
    <div className="mt-6">
      <form
        onSubmit={addRider}
        className="flex flex-col gap-2 rounded-2xl bg-surface p-4 sm:flex-row"
      >
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Nombre del corredor"
          className="w-full rounded-full border border-line bg-[var(--bg)] px-4 py-2.5 text-base outline-none focus:border-verde"
        />
        <input
          type="text"
          value={team}
          onChange={(e) => setTeam(e.target.value)}
          placeholder="País / equipo (opcional)"
          className="w-full rounded-full border border-line bg-[var(--bg)] px-4 py-2.5 text-base outline-none focus:border-verde sm:max-w-[220px]"
        />
        <button
          type="submit"
          disabled={isAdding || !name.trim()}
          className="shrink-0 rounded-full bg-amarillo px-4 py-2.5 font-display text-xs uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
        >
          {isAdding ? "Añadiendo…" : "Añadir"}
        </button>
      </form>
      {error && <p className="mt-2 text-sm text-rosa">{error}</p>}

      <div className="mt-4 flex flex-wrap items-center gap-2 text-xs">
        {CATEGORIES.map((c) => (
          <span
            key={c}
            className={`rounded-full px-3 py-1.5 font-display uppercase tracking-wide ${CATEGORY_STYLES[c]}`}
          >
            {CATEGORY_LABEL[c]} · {counts[c]}
          </span>
        ))}
        <span className="ml-auto rounded-full border border-line px-3 py-1.5 text-text-soft">
          Total: {riders.length}
        </span>
        <a
          href="/api/mundial/riders/export"
          className="rounded-full border border-line px-3 py-1.5 text-verde-deep hover:border-verde-deep"
        >
          ⬇ Descargar listado (CSV)
        </a>
      </div>
      <p className="mt-1.5 text-[11px] text-text-faint">
        El CSV trae país y categoría de cada corredor; en Excel/Sheets puedes
        reordenarlo por la columna que quieras.
      </p>

      <input
        type="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Buscar corredor o país…"
        className="mt-4 w-full rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
      />

      <div className="mt-3 flex flex-wrap items-center gap-2">
        <span className="text-xs text-text-soft">Color:</span>
        <button
          type="button"
          onClick={() => setCategoryFilter("all")}
          className={`rounded-full border px-3 py-1.5 font-display text-xs uppercase tracking-wide ${
            categoryFilter === "all"
              ? "border-verde-deep bg-verde-deep text-on-accent"
              : "border-line bg-surface text-text-soft"
          }`}
        >
          Todos
        </button>
        {CATEGORIES.map((c) => (
          <button
            key={c}
            type="button"
            onClick={() => setCategoryFilter((prev) => (prev === c ? "all" : c))}
            aria-pressed={categoryFilter === c}
            className={`rounded-full px-3 py-1.5 font-display text-xs uppercase tracking-wide transition ${CATEGORY_STYLES[c]} ${
              categoryFilter === c
                ? "ring-2 ring-offset-1 ring-verde-deep"
                : categoryFilter === "all"
                ? ""
                : "opacity-40"
            }`}
          >
            {CATEGORY_LABEL[c]}
          </button>
        ))}
      </div>

      <div className="mt-4 flex flex-col gap-1.5">
        {filtered.map((rider) => {
          const isEditing = editingId === rider.id;
          return (
            <div
              key={rider.id}
              className="rounded-xl border border-line bg-surface px-3.5 py-2.5"
            >
              {isEditing ? (
                <div className="flex flex-col gap-2">
                  <div className="flex flex-col gap-2 sm:flex-row">
                    <input
                      type="text"
                      value={editName}
                      onChange={(e) => setEditName(e.target.value)}
                      placeholder="Nombre"
                      className="w-full rounded-full border border-line bg-[var(--bg)] px-3.5 py-2 text-sm outline-none focus:border-verde"
                    />
                    <input
                      type="text"
                      value={editTeam}
                      onChange={(e) => setEditTeam(e.target.value)}
                      placeholder="País / equipo"
                      className="w-full rounded-full border border-line bg-[var(--bg)] px-3.5 py-2 text-sm outline-none focus:border-verde sm:max-w-[220px]"
                    />
                  </div>
                  {editError && <p className="text-xs text-rosa">{editError}</p>}
                  <div className="flex gap-2">
                    <button
                      type="button"
                      disabled={isSavingEdit || !editName.trim()}
                      onClick={() => saveEdit(rider.id)}
                      className="rounded-full bg-amarillo px-3.5 py-1.5 font-display text-xs uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
                    >
                      {isSavingEdit ? "Guardando…" : "Guardar"}
                    </button>
                    <button
                      type="button"
                      onClick={cancelEdit}
                      className="rounded-full border border-line px-3.5 py-1.5 font-display text-xs uppercase tracking-wide text-text-soft"
                    >
                      Cancelar
                    </button>
                  </div>
                </div>
              ) : (
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <span className="min-w-0 flex-1 truncate">
                    <CountryFlag team={rider.team} className="mr-1.5" />
                    <span className="truncate text-base">{rider.name}</span>
                    {rider.team && (
                      <span className="ml-2 text-xs text-text-soft">{rider.team}</span>
                    )}
                  </span>
                  <div className="flex w-full flex-wrap items-center justify-end gap-2 sm:w-auto sm:shrink-0">
                    {CATEGORIES.map((c) => (
                      <button
                        key={c}
                        type="button"
                        disabled={isPending && pendingId === rider.id}
                        onClick={() => setCategory(rider.id, c)}
                        aria-pressed={rider.category === c}
                        title={CATEGORY_LABEL[c]}
                        className={`h-9 w-9 rounded-full border-2 transition ${
                          rider.category === c
                            ? `${CATEGORY_STYLES[c]} border-transparent`
                            : "border-line bg-transparent opacity-40 hover:opacity-70"
                        }`}
                      />
                    ))}
                    <button
                      type="button"
                      onClick={() => startEdit(rider)}
                      title="Editar nombre/país"
                      className="ml-1 h-9 w-9 rounded-full border border-line text-text-soft hover:border-verde-deep hover:text-verde-deep"
                    >
                      ✎
                    </button>
                    <button
                      type="button"
                      onClick={() => removeRider(rider.id)}
                      title="Eliminar"
                      className="h-9 w-9 rounded-full border border-line text-text-soft hover:border-rosa hover:text-rosa"
                    >
                      ×
                    </button>
                  </div>
                </div>
              )}
            </div>
          );
        })}
        {filtered.length === 0 && (
          <p className="text-sm text-text-soft">
            No hay corredores todavía. Añade el primero arriba.
          </p>
        )}
      </div>
    </div>
  );
}
UKT_MOBILE_V10_EOF

echo "  - src/components/team-switcher.tsx"
mkdir -p "src/components"
cat > "src/components/team-switcher.tsx" <<'UKT_MOBILE_V10_EOF'
"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

export type TeamOption = { id: string; name: string };

// Selector de equipo: aparece en Equipo Base, Last Draft y Mundial para
// que un jugador con más de un equipo pueda cambiar de cuál está
// editando, y crear equipos nuevos sin límite.
export default function TeamSwitcher({
  teams,
  activeTeamId,
}: {
  teams: TeamOption[];
  activeTeamId: string;
}) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState("");
  const [error, setError] = useState<string | null>(null);

  function switchTo(teamId: string) {
    if (teamId === activeTeamId || isPending) return;
    setError(null);
    startTransition(async () => {
      const res = await fetch("/api/teams/switch", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ teamId }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => null);
        setError(data?.error ?? "No se pudo cambiar de equipo.");
        return;
      }
      router.refresh();
    });
  }

  function createTeam() {
    const name = newName.trim();
    if (!name || isPending) return;
    setError(null);
    startTransition(async () => {
      const res = await fetch("/api/teams", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setError(data?.error ?? "No se pudo crear el equipo.");
        return;
      }
      setCreating(false);
      setNewName("");
      router.refresh();
    });
  }

  return (
    <div className="mb-4">
      {teams.length > 1 && (
        <p className="mb-1.5 text-[11px] text-text-soft">
          Tienes {teams.length} equipos — este cambio afecta solo al que
          tengas abierto ahora.
        </p>
      )}
      <div className="flex flex-wrap items-center gap-1.5">
        {teams.map((team) => (
          <button
            key={team.id}
            type="button"
            disabled={isPending}
            onClick={() => switchTo(team.id)}
            aria-pressed={team.id === activeTeamId}
            className={`rounded-full px-3.5 py-2 text-sm font-semibold transition disabled:opacity-50 ${
              team.id === activeTeamId
                ? "bg-verde-deep text-on-accent"
                : "border border-line bg-surface text-text-soft hover:border-verde-deep/50"
            }`}
          >
            {team.name}
          </button>
        ))}

        {creating ? (
          <div className="flex w-full flex-wrap items-center gap-1.5">
            <input
              type="text"
              autoFocus
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") createTeam();
                if (e.key === "Escape") {
                  setCreating(false);
                  setNewName("");
                }
              }}
              maxLength={60}
              placeholder="Nombre del equipo nuevo"
              className="min-w-0 flex-1 rounded-full border border-line bg-surface px-3 py-2 text-sm outline-none focus:border-verde"
            />
            <button
              type="button"
              disabled={!newName.trim() || isPending}
              onClick={createTeam}
              className="rounded-full bg-amarillo px-3.5 py-2 text-sm font-semibold text-on-accent disabled:opacity-40"
            >
              Crear
            </button>
            <button
              type="button"
              onClick={() => {
                setCreating(false);
                setNewName("");
              }}
              className="rounded-full px-2.5 py-2 text-sm text-text-soft underline underline-offset-2"
            >
              Cancelar
            </button>
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setCreating(true)}
            className="rounded-full border border-dashed border-line px-3.5 py-2 text-sm text-verde-deep hover:border-verde-deep"
          >
            + Nuevo equipo
          </button>
        )}
      </div>
      {error && <p className="mt-1.5 text-xs text-rosa">{error}</p>}
    </div>
  );
}
UKT_MOBILE_V10_EOF

echo "  - src/components/squad-selector.tsx"
mkdir -p "src/components"
cat > "src/components/squad-selector.tsx" <<'UKT_MOBILE_V10_EOF'
"use client";

import { useMemo, useState, useTransition } from "react";
import {
  CATEGORY_LABEL,
  SQUAD_REQUIREMENTS,
  SQUAD_SIZE,
  squadCounts,
  type RiderCategory,
} from "@/lib/riders";

export type SelectableRider = {
  id: string;
  name: string;
  team: string | null;
  division: "worldtour" | "proteam" | null;
  category: RiderCategory;
};

const CATEGORIES: RiderCategory[] = ["amarillo", "rosa", "verde"];

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
};

export default function SquadSelector({
  riders,
  initialSelectedIds,
  saveUrl,
}: {
  riders: SelectableRider[];
  initialSelectedIds: string[];
  saveUrl: string;
}) {
  const [selected, setSelected] = useState<Set<string>>(
    () => new Set(initialSelectedIds)
  );
  const [query, setQuery] = useState("");
  const [division, setDivision] = useState<"all" | "worldtour" | "proteam">("all");
  const [categoryFilter, setCategoryFilter] = useState<"all" | RiderCategory>("all");
  const [isPending, startTransition] = useTransition();
  const [feedback, setFeedback] = useState<
    { type: "ok" | "error"; text: string } | null
  >(null);

  const ridersById = useMemo(() => {
    const m = new Map<string, SelectableRider>();
    for (const r of riders) m.set(r.id, r);
    return m;
  }, [riders]);

  const counts = useMemo(() => {
    const cats = Array.from(selected)
      .map((id) => ridersById.get(id)?.category)
      .filter((c): c is RiderCategory => Boolean(c));
    return squadCounts(cats);
  }, [selected, ridersById]);

  const total = selected.size;
  const canSave =
    total === SQUAD_SIZE &&
    counts.amarillo === SQUAD_REQUIREMENTS.amarillo &&
    counts.rosa === SQUAD_REQUIREMENTS.rosa &&
    counts.verde === SQUAD_REQUIREMENTS.verde;

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return riders.filter((r) => {
      if (division !== "all" && r.division !== division) return false;
      if (categoryFilter !== "all" && r.category !== categoryFilter) return false;
      if (!q) return true;
      return (
        r.name.toLowerCase().includes(q) || (r.team ?? "").toLowerCase().includes(q)
      );
    });
  }, [riders, query, division, categoryFilter]);

  const groups = useMemo(() => {
    const byTeam = new Map<string, SelectableRider[]>();
    for (const r of filtered) {
      const key = r.team ?? "Sin equipo";
      if (!byTeam.has(key)) byTeam.set(key, []);
      byTeam.get(key)!.push(r);
    }
    return Array.from(byTeam.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [filtered]);

  function toggle(rider: SelectableRider) {
    setFeedback(null);
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(rider.id)) {
        next.delete(rider.id);
        return next;
      }
      const currentCount = squadCounts(
        Array.from(prev)
          .map((id) => ridersById.get(id)?.category)
          .filter((c): c is RiderCategory => Boolean(c))
      )[rider.category];
      if (currentCount >= SQUAD_REQUIREMENTS[rider.category]) {
        return prev; // ya está completo ese hueco, no hace nada
      }
      next.add(rider.id);
      return next;
    });
  }

  function save() {
    setFeedback(null);
    startTransition(async () => {
      const res = await fetch(saveUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ riderIds: Array.from(selected) }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setFeedback({ type: "error", text: data?.error ?? "No se pudo guardar." });
        return;
      }
      setFeedback({ type: "ok", text: "Guardado." });
    });
  }

  return (
    <div>
      <div className="flex flex-wrap items-center gap-2">
        {CATEGORIES.map((c) => (
          <span
            key={c}
            className={`rounded-full px-3 py-1.5 font-display text-sm uppercase tracking-wide ${
              counts[c] === SQUAD_REQUIREMENTS[c]
                ? CATEGORY_STYLES[c]
                : "border border-line bg-transparent text-text-soft"
            }`}
          >
            {CATEGORY_LABEL[c]} · {counts[c]}/{SQUAD_REQUIREMENTS[c]}
          </span>
        ))}
        <button
          type="button"
          disabled={!canSave || isPending}
          onClick={save}
          className="ml-auto rounded-full bg-amarillo px-4 py-2.5 font-display text-sm uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
        >
          {isPending ? "Guardando…" : `Guardar (${total}/${SQUAD_SIZE})`}
        </button>
      </div>
      {feedback && (
        <p
          className={`mt-2 text-sm ${
            feedback.type === "ok" ? "text-verde-deep" : "text-rosa"
          }`}
        >
          {feedback.text}
        </p>
      )}

      <div className="mt-4 flex flex-col gap-2 sm:flex-row">
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Buscar corredor o equipo…"
          className="w-full rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
        />
        <select
          value={division}
          onChange={(e) => setDivision(e.target.value as typeof division)}
          className="rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
        >
          <option value="all">Todas las divisiones</option>
          <option value="worldtour">World Tour</option>
          <option value="proteam">ProTeam</option>
        </select>
      </div>

      <div className="mt-3 flex flex-wrap items-center gap-2">
        <span className="text-xs text-text-soft">Color:</span>
        <button
          type="button"
          onClick={() => setCategoryFilter("all")}
          className={`rounded-full border px-3 py-1.5 font-display text-xs uppercase tracking-wide ${
            categoryFilter === "all"
              ? "border-verde-deep bg-verde-deep text-on-accent"
              : "border-line bg-surface text-text-soft"
          }`}
        >
          Todos
        </button>
        {CATEGORIES.map((c) => (
          <button
            key={c}
            type="button"
            onClick={() => setCategoryFilter((prev) => (prev === c ? "all" : c))}
            aria-pressed={categoryFilter === c}
            className={`rounded-full px-3 py-1.5 font-display text-xs uppercase tracking-wide transition ${CATEGORY_STYLES[c]} ${
              categoryFilter === c
                ? "ring-2 ring-offset-1 ring-verde-deep"
                : categoryFilter === "all"
                ? ""
                : "opacity-40"
            }`}
          >
            {CATEGORY_LABEL[c]}
          </button>
        ))}
      </div>

      <div className="mt-5 flex flex-col gap-5">
        {groups.map(([team, teamRiders]) => (
          <div key={team}>
            <h3 className="font-display text-sm uppercase tracking-wide text-verde-deep">
              {team}
            </h3>
            <div className="mt-2 flex flex-col gap-1.5">
              {teamRiders.map((rider) => {
                const isSelected = selected.has(rider.id);
                const full =
                  !isSelected && counts[rider.category] >= SQUAD_REQUIREMENTS[rider.category];
                return (
                  <button
                    key={rider.id}
                    type="button"
                    disabled={full}
                    onClick={() => toggle(rider)}
                    className={`flex items-center justify-between gap-3 rounded-xl border px-3.5 py-2.5 text-left transition ${
                      isSelected
                        ? "border-verde-deep bg-verde-deep/10"
                        : full
                        ? "border-line bg-surface opacity-40"
                        : "border-line bg-surface hover:border-verde-deep/50"
                    }`}
                  >
                    <span className="min-w-0 truncate text-base">{rider.name}</span>
                    <span
                      className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-display uppercase tracking-wide ${CATEGORY_STYLES[rider.category]}`}
                    >
                      {CATEGORY_LABEL[rider.category]}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        ))}
        {groups.length === 0 && (
          <p className="text-sm text-text-soft">No hay corredores que coincidan.</p>
        )}
      </div>
    </div>
  );
}
UKT_MOBILE_V10_EOF

echo "  - src/components/mundial-squad-selector.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-squad-selector.tsx" <<'UKT_MOBILE_V10_EOF'
"use client";

import { useMemo, useState, useTransition } from "react";
import {
  CATEGORY_LABEL,
  SQUAD_REQUIREMENTS,
  SQUAD_SIZE,
  squadCounts,
  type RiderCategory,
} from "@/lib/mundial";
import CountryFlag from "./country-flag";

export type MundialRider = {
  id: string;
  name: string;
  team: string | null;
  category: RiderCategory;
};

const CATEGORIES: RiderCategory[] = ["amarillo", "rosa", "verde"];

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
};

export default function MundialSquadSelector({
  riders,
  initialSelectedIds,
  initialTeamName,
  locked,
}: {
  riders: MundialRider[];
  initialSelectedIds: string[];
  initialTeamName: string;
  locked: boolean;
}) {
  const [selected, setSelected] = useState<Set<string>>(
    () => new Set(initialSelectedIds)
  );
  const [teamName, setTeamName] = useState(initialTeamName);
  const [query, setQuery] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<"all" | RiderCategory>("all");
  const [isPending, startTransition] = useTransition();
  const [feedback, setFeedback] = useState<
    { type: "ok" | "error"; text: string } | null
  >(null);

  const ridersById = useMemo(() => {
    const m = new Map<string, MundialRider>();
    for (const r of riders) m.set(r.id, r);
    return m;
  }, [riders]);

  const counts = useMemo(() => {
    const cats = Array.from(selected)
      .map((id) => ridersById.get(id)?.category)
      .filter((c): c is RiderCategory => Boolean(c));
    return squadCounts(cats);
  }, [selected, ridersById]);

  const total = selected.size;
  const canSave =
    !locked &&
    total === SQUAD_SIZE &&
    teamName.trim().length > 0 &&
    counts.amarillo === SQUAD_REQUIREMENTS.amarillo &&
    counts.rosa === SQUAD_REQUIREMENTS.rosa &&
    counts.verde === SQUAD_REQUIREMENTS.verde;

  // Agrupados por país en primer lugar (no alfabético por nombre): cada
  // grupo es un país, y dentro se puede seguir filtrando por color.
  const groups = useMemo(() => {
    const q = query.trim().toLowerCase();
    const byCountry = new Map<string, MundialRider[]>();
    for (const r of riders) {
      if (categoryFilter !== "all" && r.category !== categoryFilter) continue;
      if (q && !r.name.toLowerCase().includes(q) && !(r.team ?? "").toLowerCase().includes(q)) {
        continue;
      }
      const key = r.team ?? "Sin país";
      if (!byCountry.has(key)) byCountry.set(key, []);
      byCountry.get(key)!.push(r);
    }
    for (const list of byCountry.values()) {
      list.sort((a, b) => a.name.localeCompare(b.name));
    }
    return Array.from(byCountry.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [riders, query, categoryFilter]);

  function toggle(rider: MundialRider) {
    if (locked) return;
    setFeedback(null);
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(rider.id)) {
        next.delete(rider.id);
        return next;
      }
      const currentCount = squadCounts(
        Array.from(prev)
          .map((id) => ridersById.get(id)?.category)
          .filter((c): c is RiderCategory => Boolean(c))
      )[rider.category];
      if (currentCount >= SQUAD_REQUIREMENTS[rider.category]) {
        return prev;
      }
      next.add(rider.id);
      return next;
    });
  }

  function save() {
    setFeedback(null);
    startTransition(async () => {
      const res = await fetch("/api/mundial/picks", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          riderIds: Array.from(selected),
          teamName: teamName.trim(),
        }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setFeedback({ type: "error", text: data?.error ?? "No se pudo guardar." });
        return;
      }
      setFeedback({ type: "ok", text: "Guardado." });
    });
  }

  return (
    <div>
      {locked ? (
        <p className="font-display text-sm uppercase tracking-wide text-verde-deep">
          {teamName || "Sin nombre de equipo"}
        </p>
      ) : (
        <input
          type="text"
          value={teamName}
          onChange={(e) => setTeamName(e.target.value)}
          maxLength={60}
          placeholder="Nombre de tu equipo (ej. Los Rompepiernas)"
          className="w-full rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
        />
      )}

      <div className="mt-3 flex flex-wrap items-center gap-2">
        {CATEGORIES.map((c) => (
          <span
            key={c}
            className={`rounded-full px-3 py-1.5 font-display text-sm uppercase tracking-wide ${
              counts[c] === SQUAD_REQUIREMENTS[c]
                ? CATEGORY_STYLES[c]
                : "border border-line bg-transparent text-text-soft"
            }`}
          >
            {CATEGORY_LABEL[c]} · {counts[c]}/{SQUAD_REQUIREMENTS[c]}
          </span>
        ))}
        {!locked && (
          <button
            type="button"
            disabled={!canSave || isPending}
            onClick={save}
            className="ml-auto rounded-full bg-amarillo px-4 py-2.5 font-display text-sm uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
          >
            {isPending ? "Guardando…" : `Guardar (${total}/${SQUAD_SIZE})`}
          </button>
        )}
      </div>
      {feedback && (
        <p
          className={`mt-2 text-sm ${
            feedback.type === "ok" ? "text-verde-deep" : "text-rosa"
          }`}
        >
          {feedback.text}
        </p>
      )}

      {!locked && (
        <div className="mt-4 flex flex-col gap-2 sm:flex-row">
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Buscar corredor o país…"
            className="w-full rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
          />
        </div>
      )}

      <div className="mt-3 flex flex-wrap items-center gap-2">
        <span className="text-xs text-text-soft">Color:</span>
        <button
          type="button"
          onClick={() => setCategoryFilter("all")}
          className={`rounded-full border px-3 py-1.5 font-display text-xs uppercase tracking-wide ${
            categoryFilter === "all"
              ? "border-verde-deep bg-verde-deep text-on-accent"
              : "border-line bg-surface text-text-soft"
          }`}
        >
          Todos
        </button>
        {CATEGORIES.map((c) => (
          <button
            key={c}
            type="button"
            onClick={() => setCategoryFilter((prev) => (prev === c ? "all" : c))}
            aria-pressed={categoryFilter === c}
            className={`rounded-full px-3 py-1.5 font-display text-xs uppercase tracking-wide transition ${CATEGORY_STYLES[c]} ${
              categoryFilter === c
                ? "ring-2 ring-offset-1 ring-verde-deep"
                : categoryFilter === "all"
                ? ""
                : "opacity-40"
            }`}
          >
            {CATEGORY_LABEL[c]}
          </button>
        ))}
      </div>

      <div className="mt-5 flex flex-col gap-4">
        {groups.map(([country, countryRiders]) => (
          <div key={country}>
            <h3 className="font-display text-xs uppercase tracking-wide text-verde-deep">
              <CountryFlag team={country} className="mr-1.5" />
              {country}
            </h3>
            <div className="mt-1.5 flex flex-col gap-1.5">
              {countryRiders.map((rider) => {
                const isSelected = selected.has(rider.id);
                const full =
                  !isSelected && counts[rider.category] >= SQUAD_REQUIREMENTS[rider.category];
                return (
                  <button
                    key={rider.id}
                    type="button"
                    disabled={locked || full}
                    onClick={() => toggle(rider)}
                    className={`flex items-center justify-between gap-3 rounded-xl border px-3.5 py-2.5 text-left transition ${
                      isSelected
                        ? "border-verde-deep bg-verde-deep/10"
                        : full || locked
                        ? "border-line bg-surface opacity-40"
                        : "border-line bg-surface hover:border-verde-deep/50"
                    }`}
                  >
                    <span className="min-w-0 flex-1 truncate text-base">{rider.name}</span>
                    <span
                      className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-display uppercase tracking-wide ${CATEGORY_STYLES[rider.category]}`}
                    >
                      {CATEGORY_LABEL[rider.category]}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        ))}
        {groups.length === 0 && (
          <p className="text-sm text-text-soft">No hay corredores que coincidan.</p>
        )}
      </div>
    </div>
  );
}
UKT_MOBILE_V10_EOF

echo "  - src/components/mundial-team-editor.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-team-editor.tsx" <<'UKT_MOBILE_V10_EOF'
"use client";

import { useMemo, useState, useTransition } from "react";
import {
  CATEGORY_LABEL,
  SQUAD_REQUIREMENTS,
  SQUAD_SIZE,
  squadCounts,
  type RiderCategory,
} from "@/lib/mundial";
import CountryFlag from "./country-flag";

export type MundialRider = {
  id: string;
  name: string;
  team: string | null;
  category: RiderCategory;
};

const CATEGORIES: RiderCategory[] = ["amarillo", "rosa", "verde"];

const CATEGORY_STYLES: Record<RiderCategory, string> = {
  amarillo: "bg-amarillo text-on-accent",
  rosa: "bg-rosa text-on-accent",
  verde: "bg-verde text-on-accent",
};

// "Mi equipo" en modo edición: a diferencia de la Elección (agrupada por
// país, para explorar toda la lista), aquí se agrupa por color en bloques
// —Amarillo / Rosa / Verde— porque lo que importa aquí es ver de un
// vistazo si cada bloque cumple su cupo (1/2/3) y poder sumar o restar
// corredores de ese color sin salir de la pantalla. Esto también deja ver
// y corregir un equipo que dejó de cumplir el cupo porque, después de
// fichar, el admin recategorizó a uno de sus corredores.
export default function MundialTeamEditor({
  riders,
  initialSelectedIds,
  initialTeamName,
  locked,
}: {
  riders: MundialRider[];
  initialSelectedIds: string[];
  initialTeamName: string;
  locked: boolean;
}) {
  const [selected, setSelected] = useState<Set<string>>(
    () => new Set(initialSelectedIds)
  );
  const [teamName, setTeamName] = useState(initialTeamName);
  const [addingCategory, setAddingCategory] = useState<RiderCategory | null>(null);
  const [query, setQuery] = useState("");
  const [isPending, startTransition] = useTransition();
  const [feedback, setFeedback] = useState<
    { type: "ok" | "error"; text: string } | null
  >(null);

  const ridersById = useMemo(() => {
    const m = new Map<string, MundialRider>();
    for (const r of riders) m.set(r.id, r);
    return m;
  }, [riders]);

  const byCategory = useMemo(() => {
    const groups: Record<RiderCategory, MundialRider[]> = {
      amarillo: [],
      rosa: [],
      verde: [],
    };
    for (const r of riders) groups[r.category].push(r);
    for (const cat of CATEGORIES) groups[cat].sort((a, b) => a.name.localeCompare(b.name));
    return groups;
  }, [riders]);

  const counts = useMemo(() => {
    const cats = Array.from(selected)
      .map((id) => ridersById.get(id)?.category)
      .filter((c): c is RiderCategory => Boolean(c));
    return squadCounts(cats);
  }, [selected, ridersById]);

  const total = selected.size;
  const isValid =
    counts.amarillo === SQUAD_REQUIREMENTS.amarillo &&
    counts.rosa === SQUAD_REQUIREMENTS.rosa &&
    counts.verde === SQUAD_REQUIREMENTS.verde;
  const canSave = !locked && total === SQUAD_SIZE && teamName.trim().length > 0 && isValid;
  const wasInitiallyInvalid = useMemo(() => {
    const cats = initialSelectedIds
      .map((id) => ridersById.get(id)?.category)
      .filter((c): c is RiderCategory => Boolean(c));
    if (cats.length !== SQUAD_SIZE) return false;
    const c = squadCounts(cats);
    return (
      c.amarillo !== SQUAD_REQUIREMENTS.amarillo ||
      c.rosa !== SQUAD_REQUIREMENTS.rosa ||
      c.verde !== SQUAD_REQUIREMENTS.verde
    );
    // Solo se calcula una vez, con los datos con los que llegó la página.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function remove(riderId: string) {
    if (locked) return;
    setFeedback(null);
    setSelected((prev) => {
      const next = new Set(prev);
      next.delete(riderId);
      return next;
    });
  }

  function add(riderId: string) {
    if (locked) return;
    setFeedback(null);
    setSelected((prev) => new Set(prev).add(riderId));
    setAddingCategory(null);
    setQuery("");
  }

  function save() {
    setFeedback(null);
    startTransition(async () => {
      const res = await fetch("/api/mundial/picks", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          riderIds: Array.from(selected),
          teamName: teamName.trim(),
        }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setFeedback({ type: "error", text: data?.error ?? "No se pudo guardar." });
        return;
      }
      setFeedback({ type: "ok", text: "Guardado." });
    });
  }

  return (
    <div>
      {wasInitiallyInvalid && (
        <div className="mb-4 rounded-xl border border-rosa/50 bg-rosa/10 px-3.5 py-2.5 text-xs text-rosa">
          Este equipo ya no cumple 1 Amarillo + 2 Rosas + 3 Verdes — seguramente
          porque un corredor que tenías fichado cambió de color después. Ajusta
          los bloques de abajo y pulsa Guardar.
        </div>
      )}

      {locked ? (
        <p className="font-display text-sm uppercase tracking-wide text-verde-deep">
          {teamName || "Sin nombre de equipo"}
        </p>
      ) : (
        <input
          type="text"
          value={teamName}
          onChange={(e) => setTeamName(e.target.value)}
          maxLength={60}
          placeholder="Nombre de tu equipo"
          className="w-full rounded-full border border-line bg-surface px-4 py-2.5 text-base outline-none focus:border-verde"
        />
      )}

      <div className="mt-5 flex flex-col gap-4">
        {CATEGORIES.map((cat) => {
          const picked = byCategory[cat].filter((r) => selected.has(r.id));
          const required = SQUAD_REQUIREMENTS[cat];
          const ok = picked.length === required;
          const available = byCategory[cat].filter((r) => !selected.has(r.id));
          const isAdding = addingCategory === cat;
          const filteredAvailable = available.filter((r) => {
            const q = query.trim().toLowerCase();
            if (!q) return true;
            return r.name.toLowerCase().includes(q) || (r.team ?? "").toLowerCase().includes(q);
          });

          return (
            <div key={cat} className="rounded-2xl border border-line bg-surface p-3.5">
              <div className="flex items-center justify-between gap-2">
                <span
                  className={`rounded-full px-3 py-1.5 font-display text-sm uppercase tracking-wide ${
                    ok ? CATEGORY_STYLES[cat] : "border border-rosa text-rosa"
                  }`}
                >
                  {CATEGORY_LABEL[cat]} · {picked.length}/{required}
                </span>
                {!locked && !isAdding && picked.length < required && (
                  <button
                    type="button"
                    onClick={() => {
                      setAddingCategory(cat);
                      setQuery("");
                    }}
                    className="rounded-full border border-line px-3 py-1 text-xs text-verde-deep hover:border-verde-deep"
                  >
                    + Añadir
                  </button>
                )}
              </div>

              <div className="mt-2.5 flex flex-col gap-1.5">
                {picked.map((rider) => (
                  <div
                    key={rider.id}
                    className="flex items-center justify-between gap-3 rounded-xl border border-line bg-[var(--bg)] px-3.5 py-2.5"
                  >
                    <span className="min-w-0 flex-1 truncate">
                      <CountryFlag team={rider.team} className="mr-1.5" />
                      <span className="truncate text-base">{rider.name}</span>
                      {rider.team && (
                        <span className="ml-2 text-xs text-text-soft">{rider.team}</span>
                      )}
                    </span>
                    {!locked && (
                      <button
                        type="button"
                        onClick={() => remove(rider.id)}
                        title="Quitar"
                        className="h-7 w-7 shrink-0 rounded-full border border-line text-text-soft hover:border-rosa hover:text-rosa"
                      >
                        −
                      </button>
                    )}
                  </div>
                ))}
                {picked.length === 0 && (
                  <p className="text-xs text-text-faint">Ningún corredor {CATEGORY_LABEL[cat].toLowerCase()} fichado.</p>
                )}
              </div>

              {isAdding && (
                <div className="mt-3 rounded-xl border border-line bg-[var(--bg)] p-2.5">
                  <input
                    type="search"
                    autoFocus
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder={`Buscar corredor o país ${CATEGORY_LABEL[cat].toLowerCase()}…`}
                    className="w-full rounded-full border border-line bg-surface px-3.5 py-2 text-sm outline-none focus:border-verde"
                  />
                  <div className="mt-2 flex max-h-52 flex-col gap-1 overflow-y-auto">
                    {filteredAvailable.slice(0, 60).map((rider) => (
                      <button
                        key={rider.id}
                        type="button"
                        onClick={() => add(rider.id)}
                        className="flex items-center gap-2 rounded-lg px-2.5 py-1.5 text-left text-sm hover:bg-surface-2"
                      >
                        <CountryFlag team={rider.team} />
                        <span className="truncate">{rider.name}</span>
                        {rider.team && (
                          <span className="ml-auto shrink-0 text-xs text-text-soft">{rider.team}</span>
                        )}
                      </button>
                    ))}
                    {filteredAvailable.length === 0 && (
                      <p className="px-2.5 py-1.5 text-xs text-text-soft">Sin resultados.</p>
                    )}
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setAddingCategory(null);
                      setQuery("");
                    }}
                    className="mt-2 text-xs text-text-soft underline underline-offset-2"
                  >
                    Cancelar
                  </button>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {!locked && (
        <button
          type="button"
          disabled={!canSave || isPending}
          onClick={save}
          className="mt-4 w-full rounded-full bg-amarillo px-4 py-2.5 font-display text-sm uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
        >
          {isPending ? "Guardando…" : `Guardar (${total}/${SQUAD_SIZE})`}
        </button>
      )}
      {feedback && (
        <p className={`mt-2 text-sm ${feedback.type === "ok" ? "text-verde-deep" : "text-rosa"}`}>
          {feedback.text}
        </p>
      )}
    </div>
  );
}
UKT_MOBILE_V10_EOF


echo ""
echo "Archivos escritos. Creando commit..."
git add -A
git commit -m "Mejora la vista en móvil: arregla el corte en /admin y ajusta tamaños

Arregla el desbordamiento horizontal en /admin (los botones empujaban el
nombre del participante fuera de la pantalla en iPhone). De paso, varias
filas y botones de toda la app ahora saltan de línea en vez de cortarse,
los botones táctiles son algo más grandes, y el texto principal (contadores
de equipo, reglamento, fichas de carrera) es algo más grande y legible.
Sin cambios de diseño ni de colores."
git push

echo ""
echo "Archivos aplicados. No hace falta ninguna migración SQL esta vez."
