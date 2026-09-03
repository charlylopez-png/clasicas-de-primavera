#!/usr/bin/env bash
set -e

if [ ! -f db/schema.sql ]; then
  echo "ERROR: no encuentro db/schema.sql en esta carpeta."
  echo "Asegurate de estar en la raiz del repo clasicas-de-primavera antes de ejecutar este script."
  exit 1
fi

mkdir -p src/lib src/app/admin src/components src/app/corredores "src/app/api/riders/[id]" "src/app/api/admin/users/[id]" src/app/api/auth/login src/app/api/auth/signup

cat > "db/schema.sql" << 'EOF'
-- UKT — Udaberriko Klasiko Txirrindulariak — esquema inicial
-- Ejecutar una vez contra la base de datos de Vercel Postgres (Neon):
--   psql "$DATABASE_URL" -f db/schema.sql

create extension if not exists pgcrypto;

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  password_hash text not null,
  display_name text not null,
  role text not null default 'participant' check (role in ('admin', 'participant')),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  is_sanedrin boolean not null default false,
  created_at timestamptz not null default now()
);

-- El Sanedrín: hasta 3 participantes (aparte del admin) con acceso previo
-- a la base de datos de corredores para clasificarlos por categoría.
create table if not exists riders (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  team text,
  division text check (division in ('worldtour', 'proteam')),
  category text not null default 'verde' check (category in ('amarillo', 'rosa', 'verde')),
  multiplier numeric(3, 2) not null default 2.00,
  created_at timestamptz not null default now()
);

create table if not exists races (
  id uuid primary key default gen_random_uuid(),
  order_num int not null unique,
  name text not null,
  stars int not null check (stars between 2 and 5),
  multiplier numeric(3, 2) not null,
  logo_path text,
  race_date date,
  created_at timestamptz not null default now()
);

-- Equipo Base: fijo para toda la temporada (6 corredores por participante:
-- 1 amarillo + 2 rosas + 3 verdes).
create table if not exists team_base (
  user_id uuid not null references users (id) on delete cascade,
  rider_id uuid not null references riders (id) on delete cascade,
  primary key (user_id, rider_id)
);

-- Last Draft: se recompone antes de cada carrera (6 corredores por
-- participante y carrera).
create table if not exists team_last_draft (
  user_id uuid not null references users (id) on delete cascade,
  race_id uuid not null references races (id) on delete cascade,
  rider_id uuid not null references riders (id) on delete cascade,
  primary key (user_id, race_id, rider_id)
);

-- Resultados oficiales: puesto de cada corredor en cada carrera (1-20).
create table if not exists race_results (
  race_id uuid not null references races (id) on delete cascade,
  rider_id uuid not null references riders (id) on delete cascade,
  position int not null check (position between 1 and 20),
  primary key (race_id, rider_id)
);

-- Duelos Sprint: un rival distinto por carrera, sorteado al inicio de
-- temporada.
create table if not exists sprint_pairings (
  race_id uuid not null references races (id) on delete cascade,
  user_a_id uuid not null references users (id) on delete cascade,
  user_b_id uuid not null references users (id) on delete cascade,
  winner_id uuid references users (id) on delete set null,
  primary key (race_id, user_a_id, user_b_id)
);

create index if not exists idx_team_last_draft_race on team_last_draft (race_id);
create index if not exists idx_race_results_race on race_results (race_id);
create index if not exists idx_sprint_pairings_race on sprint_pairings (race_id);

-- Calendario de las 12 clásicas (orden, estrellas, coeficiente y logo).
insert into races (order_num, name, stars, multiplier, logo_path) values
  (1, 'Omloop Het Nieuwsblad', 3, 1.5, '/logos/01-omloop-het-nieuwsblad.jpg'),
  (2, 'Strade Bianche', 4, 1.75, '/logos/02-strade-bianche.png'),
  (3, 'Milano-Sanremo', 5, 2, '/logos/03-milano-sanremo.png'),
  (4, 'Ronde van Brugge', 2, 1, '/logos/04-ronde-van-brugge.jpg'),
  (5, 'E3 Saxo Classic', 3, 1.5, '/logos/05-e3-saxo-classic.png'),
  (6, 'In Flanders Fields', 2, 1, '/logos/06-gent-wevelgem-in-flanders-fields.png'),
  (7, 'Dwars door Vlaanderen', 2, 1, '/logos/07-dwars-door-vlaanderen.png'),
  (8, 'Ronde van Vlaanderen', 5, 2, '/logos/08-ronde-van-vlaanderen.png'),
  (9, 'Paris-Roubaix', 5, 2, '/logos/09-paris-roubaix.png'),
  (10, 'Amstel Gold Race', 3, 1.5, '/logos/10-amstel-gold-race.png'),
  (11, 'La Flèche Wallonne', 3, 1.5, '/logos/11-la-fleche-wallonne.png'),
  (12, 'Liège-Bastogne-Liège', 5, 2, '/logos/12-liege-bastogne-liege.png')
on conflict (order_num) do nothing;

-- Migración idempotente para una base de datos ya desplegada (ejecutar sin
-- miedo aunque las columnas ya existan):
alter table users add column if not exists is_sanedrin boolean not null default false;
alter table riders add column if not exists team text;
alter table riders add column if not exists division text;
alter table riders alter column category set default 'verde';
alter table riders alter column multiplier set default 2.00;
EOF

cat > "src/lib/auth.ts" << 'EOF'
import bcrypt from "bcryptjs";
import { SignJWT, jwtVerify } from "jose";
import { cookies } from "next/headers";

export const SESSION_COOKIE = "ukt_session";

const encodedSecret = () => {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error(
      "Falta la variable de entorno JWT_SECRET (Vercel → Project → Settings → Environment Variables)."
    );
  }
  return new TextEncoder().encode(secret);
};

export type SessionPayload = {
  userId: string;
  email: string;
  displayName: string;
  role: "admin" | "participant";
  status: "pending" | "approved" | "rejected";
  // Solo para mostrar/ocultar el enlace "Corredores" en el menú: el
  // permiso real siempre se reverifica contra la base de datos en
  // /corredores y su API, porque este campo puede quedar desactualizado
  // durante los 30 días de vida del token si el admin cambia el Sanedrín.
  sanedrin: boolean;
};

export async function hashPassword(password: string) {
  return bcrypt.hash(password, 10);
}

export async function verifyPassword(password: string, hash: string) {
  return bcrypt.compare(password, hash);
}

export async function createSessionToken(payload: SessionPayload) {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(encodedSecret());
}

export async function verifySessionToken(
  token: string
): Promise<SessionPayload | null> {
  try {
    const { payload } = await jwtVerify(token, encodedSecret());
    return payload as unknown as SessionPayload;
  } catch {
    return null;
  }
}

export async function getSession(): Promise<SessionPayload | null> {
  const store = await cookies();
  const token = store.get(SESSION_COOKIE)?.value;
  if (!token) return null;
  return verifySessionToken(token);
}

export async function setSessionCookie(payload: SessionPayload) {
  const token = await createSessionToken(payload);
  const store = await cookies();
  store.set(SESSION_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 30,
  });
}

export async function clearSessionCookie() {
  const store = await cookies();
  store.delete(SESSION_COOKIE);
}
EOF

cat > "src/lib/riders.ts" << 'EOF'
export type RiderCategory = "amarillo" | "rosa" | "verde";

// Debe coincidir siempre con las CategoryCard de /reglamento.
export const CATEGORY_MULTIPLIER: Record<RiderCategory, number> = {
  amarillo: 1,
  rosa: 1.5,
  verde: 2,
};

export const CATEGORY_LABEL: Record<RiderCategory, string> = {
  amarillo: "Amarillo",
  rosa: "Rosa",
  verde: "Verde",
};
EOF

cat > "src/proxy.ts" << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { jwtVerify } from "jose";
import { SESSION_COOKIE } from "@/lib/auth";

// Routes that require an authenticated session at all.
const PROTECTED_PREFIXES = ["/mi-equipo", "/clasificacion", "/admin", "/pendiente", "/corredores"];
const ADMIN_PREFIX = "/admin";
const PUBLIC_AUTH_PATHS = ["/login", "/signup"];

async function readSession(token: string | undefined) {
  if (!token || !process.env.JWT_SECRET) return null;
  try {
    const { payload } = await jwtVerify(
      token,
      new TextEncoder().encode(process.env.JWT_SECRET)
    );
    return payload as {
      role?: string;
      status?: string;
    };
  } catch {
    return null;
  }
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const token = request.cookies.get(SESSION_COOKIE)?.value;
  const session = await readSession(token);

  const isProtected = PROTECTED_PREFIXES.some((p) => pathname.startsWith(p));
  const isAuthPage = PUBLIC_AUTH_PATHS.some((p) => pathname.startsWith(p));

  if (isAuthPage && session && session.status === "approved") {
    return NextResponse.redirect(new URL("/mi-equipo", request.url));
  }

  if (!isProtected) {
    return NextResponse.next();
  }

  if (!session) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("next", pathname);
    return NextResponse.redirect(loginUrl);
  }

  if (pathname.startsWith(ADMIN_PREFIX) && session.role !== "admin") {
    return NextResponse.redirect(new URL("/mi-equipo", request.url));
  }

  if (
    !pathname.startsWith("/pendiente") &&
    session.role !== "admin" &&
    session.status !== "approved"
  ) {
    return NextResponse.redirect(new URL("/pendiente", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/mi-equipo/:path*",
    "/clasificacion/:path*",
    "/admin/:path*",
    "/pendiente/:path*",
    "/corredores/:path*",
    "/login",
    "/signup",
  ],
};
EOF

cat > "src/app/api/auth/login/route.ts" << 'EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { verifyPassword, setSessionCookie } from "@/lib/auth";

const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = LoginSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Datos inválidos." }, { status: 400 });
  }

  const normalizedEmail = parsed.data.email.trim().toLowerCase();
  const rows = await sql`
    select id, email, password_hash, display_name, role, status, is_sanedrin
    from users where email = ${normalizedEmail}
  `;
  const user = rows[0];

  if (!user || !(await verifyPassword(parsed.data.password, user.password_hash))) {
    return NextResponse.json(
      { error: "Email o contraseña incorrectos." },
      { status: 401 }
    );
  }

  await setSessionCookie({
    userId: user.id,
    email: user.email,
    displayName: user.display_name,
    role: user.role,
    status: user.status,
    sanedrin: Boolean(user.is_sanedrin),
  });

  return NextResponse.json({ ok: true, status: user.status });
}
EOF

cat > "src/app/api/auth/signup/route.ts" << 'EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { hashPassword, setSessionCookie } from "@/lib/auth";

const SignupSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8, "La contraseña debe tener al menos 8 caracteres."),
  displayName: z.string().min(2, "Dinos cómo te llamas.").max(60),
});

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = SignupSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: parsed.error.issues[0]?.message ?? "Datos inválidos." },
      { status: 400 }
    );
  }

  const { email, password, displayName } = parsed.data;
  const normalizedEmail = email.trim().toLowerCase();

  const existing = await sql`select id from users where email = ${normalizedEmail}`;
  if (existing.length > 0) {
    return NextResponse.json(
      { error: "Ya existe una cuenta con ese email." },
      { status: 409 }
    );
  }

  const passwordHash = await hashPassword(password);
  const adminEmail = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const isAdmin = adminEmail && normalizedEmail === adminEmail;

  const [user] = await sql`
    insert into users (email, password_hash, display_name, role, status)
    values (
      ${normalizedEmail},
      ${passwordHash},
      ${displayName.trim()},
      ${isAdmin ? "admin" : "participant"},
      ${isAdmin ? "approved" : "pending"}
    )
    returning id, email, display_name, role, status
  `;

  await setSessionCookie({
    userId: user.id,
    email: user.email,
    displayName: user.display_name,
    role: user.role,
    status: user.status,
    sanedrin: false,
  });

  return NextResponse.json({ ok: true, status: user.status });
}
EOF

cat > "src/app/api/admin/users/[id]/route.ts" << 'EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";

const ActionSchema = z.object({
  action: z.enum(["approve", "reject", "sanedrin_on", "sanedrin_off"]),
});

const SANEDRIN_LIMIT = 3;

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const { id } = await params;
  const body = await request.json().catch(() => null);
  const parsed = ActionSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Acción inválida." }, { status: 400 });
  }

  if (parsed.data.action === "approve" || parsed.data.action === "reject") {
    const nextStatus = parsed.data.action === "approve" ? "approved" : "rejected";
    await sql`update users set status = ${nextStatus} where id = ${id}`;
    return NextResponse.json({ ok: true, status: nextStatus });
  }

  // El Sanedrín: como mucho 3 participantes a la vez.
  if (parsed.data.action === "sanedrin_on") {
    const [{ count }] = (await sql`
      select count(*)::int as count from users where is_sanedrin = true
    `) as { count: number }[];
    if (count >= SANEDRIN_LIMIT) {
      return NextResponse.json(
        { error: `Ya hay ${SANEDRIN_LIMIT} participantes en el Sanedrín. Quita uno antes de añadir otro.` },
        { status: 400 }
      );
    }
    await sql`update users set is_sanedrin = true where id = ${id}`;
    return NextResponse.json({ ok: true, is_sanedrin: true });
  }

  await sql`update users set is_sanedrin = false where id = ${id}`;
  return NextResponse.json({ ok: true, is_sanedrin: false });
}
EOF

cat > "src/app/admin/page.tsx" << 'EOF'
import { sql } from "@/lib/db";
import UserActions from "@/components/user-actions";
import SanedrinToggle from "@/components/sanedrin-toggle";

type UserRow = {
  id: string;
  email: string;
  display_name: string;
  status: "pending" | "approved" | "rejected";
  role: "admin" | "participant";
  is_sanedrin: boolean;
  created_at: string;
};

const SANEDRIN_LIMIT = 3;

export default async function AdminPage() {
  const users = (await sql`
    select id, email, display_name, status, role, is_sanedrin, created_at
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
                className="flex items-center justify-between gap-3 rounded-xl border border-line bg-surface p-3"
              >
                <div className="min-w-0">
                  <div className="truncate text-sm font-semibold">{u.display_name}</div>
                  <div className="truncate text-xs text-text-soft">{u.email}</div>
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
              className="flex items-center justify-between gap-3 rounded-xl border border-line bg-surface p-3"
            >
              <div className="min-w-0">
                <div className="truncate text-sm font-semibold">{u.display_name}</div>
                <div className="truncate text-xs text-text-soft">{u.email}</div>
              </div>
              <div className="flex shrink-0 items-center gap-2">
                <span
                  className={`shrink-0 rounded-full px-2.5 py-1 text-[11px] font-semibold ${
                    u.status === "approved"
                      ? "bg-verde text-[var(--hero-text)]"
                      : "bg-rosa text-white"
                  }`}
                >
                  {u.status === "approved" ? "Aprobado" : "Rechazado"}
                  {u.role === "admin" ? " · Admin" : ""}
                </span>
                {u.status === "approved" && u.role !== "admin" && (
                  <SanedrinToggle
                    userId={u.id}
                    isSanedrin={u.is_sanedrin}
                    disabled={sanedrinCount >= SANEDRIN_LIMIT}
                  />
                )}
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
EOF

cat > "src/components/sanedrin-toggle.tsx" << 'EOF'
"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

export default function SanedrinToggle({
  userId,
  isSanedrin,
  disabled,
}: {
  userId: string;
  isSanedrin: boolean;
  disabled?: boolean;
}) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function toggle() {
    setError(null);
    startTransition(async () => {
      const res = await fetch(`/api/admin/users/${userId}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: isSanedrin ? "sanedrin_off" : "sanedrin_on" }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => null);
        setError(data?.error ?? "No se pudo actualizar.");
        return;
      }
      router.refresh();
    });
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <button
        type="button"
        disabled={isPending || (disabled && !isSanedrin)}
        onClick={toggle}
        className={`shrink-0 rounded-full px-3 py-1.5 font-display text-[11px] uppercase tracking-wide disabled:opacity-50 ${
          isSanedrin
            ? "bg-verde-deep text-white"
            : "border border-verde-deep text-verde-deep"
        }`}
      >
        {isSanedrin ? "Sanedrín ✓" : "Sanedrín"}
      </button>
      {error && <span className="max-w-[10rem] text-right text-[10px] text-rosa">{error}</span>}
    </div>
  );
}
EOF

cat > "src/app/corredores/page.tsx" << 'EOF'
import { redirect } from "next/navigation";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import RidersManager, { type Rider } from "@/components/riders-manager";

export default async function CorredoresPage() {
  const session = await getSession();
  if (!session) redirect("/login");

  // No nos fiamos del JWT para el permiso de Sanedrín: se reconsulta
  // siempre en caliente, porque el admin puede cambiarlo en cualquier
  // momento y el token dura 30 días.
  let allowed = session.role === "admin";
  if (!allowed) {
    const rows = await sql`
      select is_sanedrin from users where id = ${session.userId}
    `;
    allowed = Boolean(rows[0]?.is_sanedrin);
  }
  if (!allowed) redirect("/mi-equipo");

  const riders = (await sql`
    select id, name, team, division, category, multiplier
    from riders
    order by division, team, name
  `) as Rider[];

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        El Sanedrín
      </div>
      <h1 className="text-2xl text-verde-deep">Base de datos de corredores</h1>
      <p className="mt-2 max-w-prose text-sm text-text-soft">
        World Tour y ProTeam, temporada 2026 (datos de partida, se
        sustituirán más adelante por la temporada real). Por defecto todos
        están en Verde: reclasifica aquí a los favoritos en Amarillo y a los
        candidatos serios en Rosa.
      </p>

      <RidersManager initialRiders={riders} />
    </div>
  );
}
EOF

cat > "src/components/riders-manager.tsx" << 'EOF'
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
  amarillo: "bg-amarillo text-[#372802]",
  rosa: "bg-rosa text-white",
  verde: "bg-verde text-[var(--hero-text)]",
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
      <div className="flex flex-wrap gap-2 text-[11px]">
        {CATEGORIES.map((c) => (
          <span
            key={c}
            className={`rounded-full px-2.5 py-1 font-display uppercase tracking-wide ${CATEGORY_STYLES[c]}`}
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
          className="w-full rounded-full border border-line bg-surface px-4 py-2 text-sm outline-none focus:border-verde"
        />
        <select
          value={division}
          onChange={(e) => setDivision(e.target.value as typeof division)}
          className="rounded-full border border-line bg-surface px-4 py-2 text-sm outline-none focus:border-verde"
        >
          <option value="all">Todas las divisiones</option>
          <option value="worldtour">World Tour</option>
          <option value="proteam">ProTeam</option>
        </select>
      </div>

      <div className="mt-5 flex flex-col gap-6">
        {groups.map(([team, teamRiders]) => (
          <div key={team}>
            <h3 className="font-display text-xs uppercase tracking-wide text-verde-deep">
              {team}
            </h3>
            <div className="mt-2 flex flex-col gap-1.5">
              {teamRiders.map((rider) => (
                <div
                  key={rider.id}
                  className="flex items-center justify-between gap-3 rounded-xl border border-line bg-surface px-3 py-2"
                >
                  <span className="min-w-0 truncate text-sm">{rider.name}</span>
                  <div className="flex shrink-0 gap-1">
                    {CATEGORIES.map((c) => (
                      <button
                        key={c}
                        type="button"
                        disabled={isPending && pendingId === rider.id}
                        onClick={() => setCategory(rider.id, c)}
                        aria-pressed={rider.category === c}
                        title={CATEGORY_LABEL[c]}
                        className={`h-6 w-6 rounded-full border-2 transition ${
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
EOF

cat > "src/app/api/riders/[id]/route.ts" << 'EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { CATEGORY_MULTIPLIER } from "@/lib/riders";

const PatchSchema = z.object({
  category: z.enum(["amarillo", "rosa", "verde"]),
});

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "No autorizado." }, { status: 401 });
  }

  // El rol admin es inmutable y viene del JWT, pero el permiso de
  // Sanedrín se reconsulta siempre en caliente (puede cambiar mientras
  // el token de 30 días sigue vivo).
  let allowed = session.role === "admin";
  if (!allowed) {
    const rows = await sql`
      select is_sanedrin from users where id = ${session.userId}
    `;
    allowed = Boolean(rows[0]?.is_sanedrin);
  }
  if (!allowed) {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const { id } = await params;
  const body = await request.json().catch(() => null);
  const parsed = PatchSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Categoría inválida." }, { status: 400 });
  }

  const multiplier = CATEGORY_MULTIPLIER[parsed.data.category];
  await sql`
    update riders
    set category = ${parsed.data.category}, multiplier = ${multiplier}
    where id = ${id}
  `;

  return NextResponse.json({ ok: true, category: parsed.data.category, multiplier });
}
EOF

cat > "src/components/site-header.tsx" << 'EOF'
import Link from "next/link";
import type { SessionPayload } from "@/lib/auth";
import LogoutButton from "@/components/logout-button";
import MobileNav from "@/components/mobile-nav";
import Logo from "@/components/logo";

type NavItem = { href: string; label: string };

export default function SiteHeader({
  session,
}: {
  session: SessionPayload | null;
}) {
  const navItems: NavItem[] = [
    { href: "/reglamento", label: "Reglamento" },
    { href: "/calendario", label: "Calendario" },
  ];
  if (session?.status === "approved") {
    navItems.push(
      { href: "/mi-equipo", label: "Mi equipo" },
      { href: "/clasificacion", label: "Clasificación" }
    );
  }
  if (session?.role === "admin" || session?.sanedrin) {
    navItems.push({ href: "/corredores", label: "Corredores" });
  }
  if (session?.role === "admin") {
    navItems.push({ href: "/admin", label: "Admin" });
  }

  return (
    <header className="sticky top-0 z-20 relative border-b border-line bg-[var(--bg)]/92 backdrop-blur-sm">
      <div className="mx-auto flex max-w-4xl items-center justify-between gap-4 px-5 py-2.5">
        <Link href="/" aria-label="UKT — Inicio" className="shrink-0">
          <Logo className="h-8 w-auto sm:h-9" />
        </Link>

        <nav className="hidden items-center gap-1 sm:flex">
          {navItems.map((item) => (
            <NavLink key={item.href} href={item.href}>
              {item.label}
            </NavLink>
          ))}
          <AuthActions session={session} />
        </nav>

        <MobileNav items={navItems}>
          <AuthActions session={session} />
        </MobileNav>
      </div>
    </header>
  );
}

function AuthActions({ session }: { session: SessionPayload | null }) {
  if (session) {
    return <LogoutButton />;
  }
  return (
    <div className="flex items-center gap-2 sm:gap-2">
      <NavLink href="/login">Entrar</NavLink>
      <Link
        href="/signup"
        className="rounded-full bg-verde px-4 py-2.5 text-center font-display text-xs uppercase tracking-wide text-[var(--hero-text)] sm:ml-1 sm:px-3.5 sm:py-2"
      >
        Crear cuenta
      </Link>
    </div>
  );
}

function NavLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="rounded-full px-3.5 py-2 font-display text-xs uppercase tracking-wide text-[var(--pill-text)] hover:bg-[var(--pill-bg)]"
    >
      {children}
    </Link>
  );
}
EOF

cat > "src/app/reglamento/page.tsx" << 'EOF'
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
                i < 3 ? "bg-amarillo text-[#2b2103] font-bold" : "bg-surface"
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
            className="bg-gradient-to-br from-[#f0c23a] to-[#c68a06] text-[#372802]"
          >
            Top élite y favoritos indiscutibles (Pogačar, MVDP…). Ganan a
            menudo, pero apenas multiplican.
          </CategoryCard>
          <CategoryCard
            name="Rosa"
            mult="×1,5"
            className="bg-gradient-to-br from-[#ef6ea0] to-[#c53f74] text-white"
          >
            Corredores de élite, candidatos serios sin ser los favoritos
            absolutos.
          </CategoryCard>
          <CategoryCard
            name="Verde"
            mult="×2"
            className="bg-gradient-to-br from-[#4fa576] to-[#215f3e] text-white"
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
          style={{ background: "linear-gradient(135deg, var(--accent-rosa, #c53f74), #a63464)" }}
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
      <p className="mt-1.5 text-[13px] leading-relaxed text-text-soft">
        {children}
      </p>
    </div>
  );
}

function Example({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-xl bg-white/5 p-3 text-[13px] leading-relaxed">
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
      <p className="mt-1.5 text-[13px] leading-relaxed">{children}</p>
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
EOF

git add -A
git commit -m "Anade el Sanedrin: permisos y base de datos de corredores

- users.is_sanedrin: hasta 3 participantes (aparte del admin) con
  acceso previo a la base de datos de corredores
- riders: nuevas columnas team/division, categoria por defecto verde
- /corredores: pagina para clasificar corredores en Amarillo/Rosa/Verde,
  con permiso reverificado en caliente contra la base de datos (no se
  fia del JWT para este permiso, que puede cambiar en cualquier momento)
- /api/riders/[id]: PATCH para cambiar la categoria de un corredor
  (recalcula el coeficiente automaticamente)
- /admin: boton para asignar/quitar el Sanedrin, con tope de 3
- corrige la inconsistencia de coeficientes en /reglamento (Rosa x1,5,
  Verde x2, en vez de x2/x3)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016LatMv4fA2uvbQTCSnJG6u"
git push
