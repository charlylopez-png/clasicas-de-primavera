#!/usr/bin/env bash
set -euo pipefail

# apply-mundial-v6.sh — dos cosas a la vez:
#
# 1) Un botón "Descargar listado (CSV)" en /mundial/corredores (admin) que
#    exporta a todos los corredores del Mundial con su país y categoría.
#
# 2) "Jugadores manuales": desde /admin puedes añadir un jugador con solo
#    su nombre (sin cuenta ni contraseña) y usar "Actuar como" para entrar
#    en su nombre y fichar por él exactamente como haría cualquier
#    jugador — tanto en las clásicas (Equipo Base, Last Draft de cada
#    carrera) como en el Mundial. Mientras actúas como otro aparece una
#    barra amarilla arriba de todo con un botón para volver a tu cuenta.
#
# IMPORTANTE: esta vez SÍ hay que ejecutar un .sql en Neon —
# db/manual_players_migration.sql (añade una sola columna a la tabla de
# usuarios, no toca nada más).
#
# Ejecuta esto DESDE LA RAÍZ del repo (donde está db/schema.sql), con el
# Codespace ya abierto. Requiere haber aplicado antes apply-mundial-v5.sh.

if [ ! -f "db/schema.sql" ]; then
  echo "Error: no se encuentra db/schema.sql en el directorio actual."
  echo "Ejecuta este script desde la raíz del repo clasicas-de-primavera."
  exit 1
fi

echo "Aplicando descarga de corredores y jugadores manuales (v6)..."

echo "  - src/app/api/mundial/riders/export/route.ts"
mkdir -p "src/app/api/mundial/riders/export"
cat > "src/app/api/mundial/riders/export/route.ts" <<'UKT_MUNDIAL_V6_EOF'
import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { CATEGORY_LABEL, MUNDIAL_SLUG, type RiderCategory } from "@/lib/mundial";

// Orden de categoría en el CSV (no alfabético): Amarillo, Rosa, Verde.
const CATEGORY_ORDER: RiderCategory[] = ["amarillo", "rosa", "verde"];

function csvEscape(value: string): string {
  if (/[";\n]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

export async function GET() {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const events = await sql`select id from special_events where slug = ${MUNDIAL_SLUG}`;
  const eventId = events[0]?.id;
  if (!eventId) {
    return NextResponse.json({ error: "No se encuentra el evento del Mundial." }, { status: 500 });
  }

  const rows = (await sql`
    select name, team, category
    from special_event_riders
    where event_id = ${eventId}
  `) as { name: string; team: string | null; category: RiderCategory }[];

  // Agrupado primero por categoría y, dentro, por país — así se ve de un
  // vistazo cada bloque de color; en Excel se puede reordenar por la
  // columna País con un clic si se prefiere esa agrupación.
  rows.sort((a, b) => {
    const catDiff = CATEGORY_ORDER.indexOf(a.category) - CATEGORY_ORDER.indexOf(b.category);
    if (catDiff !== 0) return catDiff;
    const teamDiff = (a.team ?? "").localeCompare(b.team ?? "", "es");
    if (teamDiff !== 0) return teamDiff;
    return a.name.localeCompare(b.name, "es");
  });

  const lines = [["Categoría", "País", "Corredor"].join(";")];
  for (const r of rows) {
    lines.push(
      [csvEscape(CATEGORY_LABEL[r.category]), csvEscape(r.team ?? ""), csvEscape(r.name)].join(";")
    );
  }
  // BOM para que Excel detecte UTF-8 y no rompa los acentos/ñ; ";" como
  // separador porque en Excel con configuración regional española la coma
  // es el separador decimal.
  const csv = "﻿" + lines.join("\r\n") + "\r\n";

  return new NextResponse(csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": 'attachment; filename="mundial-corredores.csv"',
    },
  });
}
UKT_MUNDIAL_V6_EOF

echo "  - src/components/mundial-riders-manager.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-riders-manager.tsx" <<'UKT_MUNDIAL_V6_EOF'
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
                <div className="flex items-center justify-between gap-3">
                  <span className="min-w-0 flex-1 truncate">
                    <CountryFlag team={rider.team} className="mr-1.5" />
                    <span className="truncate text-base">{rider.name}</span>
                    {rider.team && (
                      <span className="ml-2 text-xs text-text-soft">{rider.team}</span>
                    )}
                  </span>
                  <div className="flex shrink-0 items-center gap-1.5">
                    {CATEGORIES.map((c) => (
                      <button
                        key={c}
                        type="button"
                        disabled={isPending && pendingId === rider.id}
                        onClick={() => setCategory(rider.id, c)}
                        aria-pressed={rider.category === c}
                        title={CATEGORY_LABEL[c]}
                        className={`h-8 w-8 rounded-full border-2 transition ${
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
                      className="ml-1 h-8 w-8 rounded-full border border-line text-text-soft hover:border-verde-deep hover:text-verde-deep"
                    >
                      ✎
                    </button>
                    <button
                      type="button"
                      onClick={() => removeRider(rider.id)}
                      title="Eliminar"
                      className="h-8 w-8 rounded-full border border-line text-text-soft hover:border-rosa hover:text-rosa"
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
UKT_MUNDIAL_V6_EOF

echo "  - src/lib/auth.ts"
mkdir -p "src/lib"
cat > "src/lib/auth.ts" <<'UKT_MUNDIAL_V6_EOF'
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

// "Actuar como": deja que el admin entre temporalmente en la sesión de
// otro jugador (típicamente uno "manual", sin cuenta propia) para hacer
// por él los mismos pasos que haría cualquiera — Equipo Base, Last Draft,
// elección del Mundial… — sin tener que construir una pantalla aparte
// para cada cosa. La sesión de admin no se pierde: se guarda en una
// segunda cookie mientras dura la suplantación, y "Volver a mi cuenta" la
// restaura.
export const IMPERSONATE_COOKIE = "ukt_admin_backup";

export async function startImpersonation(targetPayload: SessionPayload) {
  const store = await cookies();
  const adminToken = store.get(SESSION_COOKIE)?.value;
  if (adminToken) {
    store.set(IMPERSONATE_COOKIE, adminToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      // Misma duración que una sesión normal: si caducara antes que la
      // suplantación, el admin se quedaría atrapado en la otra cuenta sin
      // aviso (la barra de "Actuando como" desaparecería sin más).
      maxAge: 60 * 60 * 24 * 30,
    });
  }
  await setSessionCookie(targetPayload);
}

// Devuelve la sesión de admin guardada, o null si no se estaba
// suplantando a nadie (no toca cookies).
export async function getImpersonationAdmin(): Promise<SessionPayload | null> {
  const store = await cookies();
  const token = store.get(IMPERSONATE_COOKIE)?.value;
  if (!token) return null;
  return verifySessionToken(token);
}

// Restaura la sesión de admin guardada. Devuelve false si no había
// ninguna que restaurar (por ejemplo, la cookie caducó a las 4h).
export async function stopImpersonation(): Promise<boolean> {
  const store = await cookies();
  const adminToken = store.get(IMPERSONATE_COOKIE)?.value;
  store.delete(IMPERSONATE_COOKIE);
  if (!adminToken) return false;

  store.set(SESSION_COOKIE, adminToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 30,
  });
  return true;
}
UKT_MUNDIAL_V6_EOF

echo "  - src/app/api/auth/login/route.ts"
mkdir -p "src/app/api/auth/login"
cat > "src/app/api/auth/login/route.ts" <<'UKT_MUNDIAL_V6_EOF'
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
    select id, email, password_hash, display_name, role, status, is_sanedrin, is_manual
    from users where email = ${normalizedEmail}
  `;
  const user = rows[0];

  if (
    !user ||
    user.is_manual ||
    !(await verifyPassword(parsed.data.password, user.password_hash))
  ) {
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
UKT_MUNDIAL_V6_EOF

echo "  - src/app/api/admin/manual-players/route.ts"
mkdir -p "src/app/api/admin/manual-players"
cat > "src/app/api/admin/manual-players/route.ts" <<'UKT_MUNDIAL_V6_EOF'
import { NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { z } from "zod";
import { sql } from "@/lib/db";
import { getSession, hashPassword } from "@/lib/auth";

const BodySchema = z.object({
  displayName: z.string().trim().min(1).max(60),
});

// Jugadores "manuales": gente que no usa la app (mayores con dificultades
// con la tecnología, por ejemplo) a los que el admin quiere apuntar de
// todas formas — tanto a las clásicas como al Mundial. Se guardan como
// una fila más de `users`, con is_manual = true y una contraseña al azar
// que nunca se entrega a nadie, así que en la práctica no pueden iniciar
// sesión (y el login además los rechaza explícitamente por si acaso). El
// admin actúa por ellos entrando en su nombre con "Actuar como" desde
// /admin — así hace exactamente los mismos pasos que haría cualquier
// jugador (Equipo Base, Last Draft, elección del Mundial…), sin tener que
// duplicar cada pantalla.
export async function POST(request: Request) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Ponle un nombre al jugador." }, { status: 400 });
  }

  const placeholderEmail = `manual-${randomUUID()}@ukt.invalid`;
  const unusablePassword = await hashPassword(randomUUID());

  const rows = await sql`
    insert into users (email, password_hash, display_name, role, status, is_manual)
    values (${placeholderEmail}, ${unusablePassword}, ${parsed.data.displayName}, 'participant', 'approved', true)
    returning id, display_name
  `;

  return NextResponse.json({
    ok: true,
    player: { id: rows[0].id, displayName: rows[0].display_name },
  });
}
UKT_MUNDIAL_V6_EOF

echo "  - src/app/api/admin/manual-players/[id]/route.ts"
mkdir -p "src/app/api/admin/manual-players/[id]"
cat > "src/app/api/admin/manual-players/[id]/route.ts" <<'UKT_MUNDIAL_V6_EOF'
import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";

// Solo borra si is_manual = true, para que este endpoint no pueda usarse
// nunca para eliminar una cuenta real por error. El borrado en cascada ya
// existente (special_event_picks/squads referencian users con ON DELETE
// CASCADE) limpia también su ficha y su equipo del Mundial.
export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const { id } = await params;
  const rows = await sql`
    delete from users where id = ${id} and is_manual = true
    returning id
  `;
  if (!rows[0]) {
    return NextResponse.json(
      { error: "No se encuentra ese jugador manual." },
      { status: 404 }
    );
  }

  return NextResponse.json({ ok: true });
}
UKT_MUNDIAL_V6_EOF

echo "  - src/app/api/admin/impersonate/route.ts"
mkdir -p "src/app/api/admin/impersonate"
cat > "src/app/api/admin/impersonate/route.ts" <<'UKT_MUNDIAL_V6_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { getSession, startImpersonation } from "@/lib/auth";

const BodySchema = z.object({ userId: z.string().uuid() });

export async function POST(request: Request) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Jugador no válido." }, { status: 400 });
  }

  const rows = await sql`
    select id, email, display_name, role, status, is_sanedrin
    from users where id = ${parsed.data.userId}
  `;
  const target = rows[0];
  if (!target) {
    return NextResponse.json({ error: "No se encuentra ese jugador." }, { status: 404 });
  }
  if (target.role === "admin") {
    return NextResponse.json(
      { error: "No puedes actuar como otro admin." },
      { status: 400 }
    );
  }

  await startImpersonation({
    userId: target.id,
    email: target.email,
    displayName: target.display_name,
    role: target.role,
    status: target.status,
    sanedrin: Boolean(target.is_sanedrin),
  });

  return NextResponse.json({ ok: true });
}
UKT_MUNDIAL_V6_EOF

echo "  - src/app/api/admin/stop-impersonate/route.ts"
mkdir -p "src/app/api/admin/stop-impersonate"
cat > "src/app/api/admin/stop-impersonate/route.ts" <<'UKT_MUNDIAL_V6_EOF'
import { NextResponse } from "next/server";
import { stopImpersonation } from "@/lib/auth";

export async function POST() {
  const restored = await stopImpersonation();
  if (!restored) {
    return NextResponse.json(
      { error: "No había ninguna sesión de admin que restaurar." },
      { status: 400 }
    );
  }
  return NextResponse.json({ ok: true });
}
UKT_MUNDIAL_V6_EOF

echo "  - src/components/manual-player-form.tsx"
mkdir -p "src/components"
cat > "src/components/manual-player-form.tsx" <<'UKT_MUNDIAL_V6_EOF'
"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

export default function ManualPlayerForm() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  function add(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    setError(null);
    startTransition(async () => {
      const res = await fetch("/api/admin/manual-players", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ displayName: name.trim() }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setError(data?.error ?? "No se pudo añadir el jugador.");
        return;
      }
      setName("");
      router.refresh();
    });
  }

  return (
    <form onSubmit={add} className="flex flex-col gap-2 rounded-xl bg-surface p-3 sm:flex-row">
      <input
        type="text"
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder="Nombre del jugador (sin cuenta propia)"
        className="w-full rounded-full border border-line bg-[var(--bg)] px-4 py-2 text-sm outline-none focus:border-verde"
      />
      <button
        type="submit"
        disabled={isPending || !name.trim()}
        className="shrink-0 rounded-full bg-amarillo px-4 py-2 font-display text-xs uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-40"
      >
        {isPending ? "Añadiendo…" : "+ Añadir"}
      </button>
      {error && <p className="text-xs text-rosa sm:self-center">{error}</p>}
    </form>
  );
}
UKT_MUNDIAL_V6_EOF

echo "  - src/components/delete-manual-player-button.tsx"
mkdir -p "src/components"
cat > "src/components/delete-manual-player-button.tsx" <<'UKT_MUNDIAL_V6_EOF'
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
      className="h-7 w-7 shrink-0 rounded-full border border-line text-text-soft hover:border-rosa hover:text-rosa disabled:opacity-50"
    >
      ×
    </button>
  );
}
UKT_MUNDIAL_V6_EOF

echo "  - src/components/impersonate-button.tsx"
mkdir -p "src/components"
cat > "src/components/impersonate-button.tsx" <<'UKT_MUNDIAL_V6_EOF'
"use client";

import { useTransition } from "react";

export default function ImpersonateButton({ userId }: { userId: string }) {
  const [isPending, startTransition] = useTransition();

  function act() {
    startTransition(async () => {
      const res = await fetch("/api/admin/impersonate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId }),
      });
      if (res.ok) {
        window.location.href = "/";
      }
    });
  }

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={act}
      className="shrink-0 rounded-full border border-line px-3 py-1.5 font-display text-[11px] uppercase tracking-wide text-verde-deep hover:border-verde-deep disabled:opacity-50"
    >
      {isPending ? "Entrando…" : "Actuar como"}
    </button>
  );
}
UKT_MUNDIAL_V6_EOF

echo "  - src/components/impersonation-bar.tsx"
mkdir -p "src/components"
cat > "src/components/impersonation-bar.tsx" <<'UKT_MUNDIAL_V6_EOF'
"use client";

import { useTransition } from "react";

export default function ImpersonationBar({ actingAsName }: { actingAsName: string }) {
  const [isPending, startTransition] = useTransition();

  function stop() {
    startTransition(async () => {
      const res = await fetch("/api/admin/stop-impersonate", { method: "POST" });
      if (res.ok) {
        window.location.href = "/admin";
      }
    });
  }

  return (
    <div className="flex flex-wrap items-center justify-center gap-2.5 bg-amarillo px-4 py-2 text-center font-display text-[11px] uppercase tracking-wide text-on-accent">
      <span>Actuando como {actingAsName}</span>
      <button
        type="button"
        disabled={isPending}
        onClick={stop}
        className="rounded-full border border-on-accent/40 px-3 py-1 hover:bg-on-accent/10 disabled:opacity-50"
      >
        {isPending ? "Volviendo…" : "Volver a mi cuenta"}
      </button>
    </div>
  );
}
UKT_MUNDIAL_V6_EOF

echo "  - src/app/admin/page.tsx"
mkdir -p "src/app/admin"
cat > "src/app/admin/page.tsx" <<'UKT_MUNDIAL_V6_EOF'
import { sql } from "@/lib/db";
import UserActions from "@/components/user-actions";
import SanedrinToggle from "@/components/sanedrin-toggle";
import ManualPlayerForm from "@/components/manual-player-form";
import DeleteManualPlayerButton from "@/components/delete-manual-player-button";
import ImpersonateButton from "@/components/impersonate-button";

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
                <div className="flex items-center gap-2">
                  <span className="truncate text-sm font-semibold">{u.display_name}</span>
                  {u.is_manual && (
                    <span className="shrink-0 rounded-full border border-line px-2 py-0.5 text-[10px] uppercase tracking-wide text-text-soft">
                      Sin cuenta
                    </span>
                  )}
                </div>
                <div className="truncate text-xs text-text-soft">
                  {u.is_manual ? "Gestionado por ti" : u.email}
                </div>
              </div>
              <div className="flex shrink-0 flex-wrap items-center justify-end gap-2">
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
UKT_MUNDIAL_V6_EOF

echo "  - src/app/layout.tsx"
mkdir -p "src/app"
cat > "src/app/layout.tsx" <<'UKT_MUNDIAL_V6_EOF'
import type { Metadata, Viewport } from "next";
import { Oswald, Nunito, Archivo_Black } from "next/font/google";
import "./globals.css";
import { getSession, getImpersonationAdmin } from "@/lib/auth";
import SiteHeader from "@/components/site-header";
import ImpersonationBar from "@/components/impersonation-bar";

const oswald = Oswald({
  variable: "--font-oswald",
  weight: ["400", "500", "600", "700"],
  subsets: ["latin"],
});

const nunito = Nunito({
  variable: "--font-nunito",
  weight: ["400", "600", "700"],
  subsets: ["latin"],
});

const archivoBlack = Archivo_Black({
  variable: "--font-archivo",
  weight: "400",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "UKT — Porra de las Clásicas de Primavera",
  description:
    "Udaberriko Klasiko Txirrindulariak: la porra ciclista de las clásicas de primavera entre amigos.",
  manifest: "/manifest.json",
  icons: {
    icon: [
      { url: "/ukt-identity/png/ukt-icon-32-favicon.png", sizes: "32x32", type: "image/png" },
      { url: "/ukt-identity/png/ukt-icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/ukt-identity/png/ukt-icon-512-cobble.png", sizes: "512x512", type: "image/png" },
    ],
    apple: [
      { url: "/ukt-identity/png/ukt-icon-180-apple.png", sizes: "180x180", type: "image/png" },
    ],
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "UKT",
  },
};

export const viewport: Viewport = {
  themeColor: "#0d2c20",
};

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await getSession();
  const impersonationAdmin = await getImpersonationAdmin();

  return (
    <html
      lang="es"
      className={`${oswald.variable} ${nunito.variable} ${archivoBlack.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-bg text-text">
        {impersonationAdmin && session && (
          <ImpersonationBar actingAsName={session.displayName} />
        )}
        <SiteHeader session={session} />
        <main className="flex-1">{children}</main>
      </body>
    </html>
  );
}
UKT_MUNDIAL_V6_EOF


echo ""
echo "Archivos escritos. Creando commit..."
git add -A
git commit -m "Descarga de corredores en CSV + jugadores manuales con 'Actuar como'

Añade un botón para descargar en CSV el listado de corredores del Mundial
(país y categoría). Y añade 'jugadores manuales': el admin puede apuntar
a la porra a gente que no va a usar la app ella misma (solo con su
nombre, sin cuenta) y actuar en su nombre desde /admin para fichar por
ella, tanto en las clásicas como en el Mundial, igual que cualquier otro
jugador."
git push

echo ""
echo "Archivos aplicados. AHORA ejecuta en el editor SQL de Neon:"
echo "  db/manual_players_migration.sql"
echo "(Añade una columna a la tabla de usuarios; no toca nada existente.)"
