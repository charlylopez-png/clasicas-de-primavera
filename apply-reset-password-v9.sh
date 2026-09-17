#!/usr/bin/env bash
set -euo pipefail

# apply-reset-password-v9.sh — añade un botón "Restablecer contraseña" en
# /admin junto a cada participante con cuenta propia (no a los jugadores
# manuales, que no tienen contraseña que restablecer). Al pulsarlo, pide
# confirmación, genera una contraseña nueva al azar y la muestra en
# pantalla UNA sola vez para que se la pases a esa persona — no queda
# guardada en ningún sitio en texto plano, solo su hash, igual que
# cualquier otra contraseña de la app.
#
# El login siempre ha sido con el email de cada uno (no hay usuario
# aparte); eso no cambia con este script.
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

echo "Aplicando restablecer contraseña (v9)..."

echo "  - src/lib/auth.ts"
mkdir -p "src/lib"
cat > "src/lib/auth.ts" <<'UKT_RESET_PW_V9_EOF'
import bcrypt from "bcryptjs";
import { randomInt } from "crypto";
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

// Para "Restablecer contraseña" desde /admin: una contraseña nueva y
// legible (sin caracteres que se confunden fácilmente al dictarla o
// pasarla por WhatsApp: sin 0/O, 1/l/I). Se genera aquí y solo se
// muestra una vez en el momento de crearla — no se guarda en ningún
// sitio en texto plano, solo su hash.
const PASSWORD_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";

export function generateRandomPassword(length = 10) {
  let out = "";
  for (let i = 0; i < length; i++) {
    out += PASSWORD_CHARS[randomInt(PASSWORD_CHARS.length)];
  }
  return out;
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
UKT_RESET_PW_V9_EOF

echo "  - src/app/api/admin/users/[id]/reset-password/route.ts"
mkdir -p "src/app/api/admin/users/[id]/reset-password"
cat > "src/app/api/admin/users/[id]/reset-password/route.ts" <<'UKT_RESET_PW_V9_EOF'
import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import { getSession, hashPassword, generateRandomPassword } from "@/lib/auth";

type UserRow = {
  id: string;
  is_manual: boolean;
};

// Genera una contraseña nueva para un participante y la devuelve en la
// respuesta — es la ÚNICA vez que se ve en texto plano; solo se guarda
// su hash. Pensado para cuando alguien ha olvidado la suya y no hay
// ("todavía) una pantalla de "olvidé mi contraseña" para que la pidan
// ellos mismos.
export async function POST(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const { id } = await params;
  const users = (await sql`
    select id, is_manual from users where id = ${id}
  `) as UserRow[];
  const user = users[0];
  if (!user) {
    return NextResponse.json({ error: "No se encuentra ese participante." }, { status: 404 });
  }
  if (user.is_manual) {
    return NextResponse.json(
      { error: "Este jugador es manual (no tiene cuenta propia): no hay contraseña que restablecer." },
      { status: 400 }
    );
  }

  const password = generateRandomPassword();
  const passwordHash = await hashPassword(password);
  await sql`update users set password_hash = ${passwordHash} where id = ${id}`;

  return NextResponse.json({ ok: true, password });
}
UKT_RESET_PW_V9_EOF

echo "  - src/components/reset-password-button.tsx"
mkdir -p "src/components"
cat > "src/components/reset-password-button.tsx" <<'UKT_RESET_PW_V9_EOF'
"use client";

import { useState, useTransition } from "react";

export default function ResetPasswordButton({
  userId,
  displayName,
}: {
  userId: string;
  displayName: string;
}) {
  const [isPending, startTransition] = useTransition();
  const [result, setResult] = useState<{ password: string } | { error: string } | null>(null);
  const [copied, setCopied] = useState(false);

  function reset() {
    const ok = window.confirm(
      `¿Restablecer la contraseña de ${displayName}? La contraseña que tenía dejará de funcionar.`
    );
    if (!ok) return;
    setResult(null);
    setCopied(false);
    startTransition(async () => {
      const res = await fetch(`/api/admin/users/${userId}/reset-password`, {
        method: "POST",
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setResult({ error: data?.error ?? "No se pudo restablecer la contraseña." });
        return;
      }
      setResult({ password: data.password });
    });
  }

  async function copy(password: string) {
    try {
      await navigator.clipboard.writeText(password);
      setCopied(true);
    } catch {
      // Portapapeles no disponible (por ejemplo, sin HTTPS): el admin
      // puede seleccionar y copiar la contraseña a mano.
    }
  }

  return (
    <div className="flex flex-col items-end gap-1.5">
      <button
        type="button"
        disabled={isPending}
        onClick={reset}
        className="shrink-0 rounded-full border border-line px-3 py-1.5 font-display text-[11px] uppercase tracking-wide text-verde-deep hover:border-verde-deep disabled:opacity-50"
      >
        {isPending ? "Restableciendo…" : "Restablecer contraseña"}
      </button>

      {result && "password" in result && (
        <div className="max-w-[220px] rounded-lg border border-verde-deep/40 bg-verde-deep/10 px-2.5 py-1.5 text-right">
          <p className="text-[10px] leading-tight text-text-soft">
            Nueva contraseña — pásasela ahora, no se volverá a mostrar:
          </p>
          <div className="mt-1 flex items-center justify-end gap-1.5">
            <code className="select-all font-mono text-sm text-verde-deep">
              {result.password}
            </code>
            <button
              type="button"
              onClick={() => copy(result.password)}
              className="shrink-0 text-[11px] text-verde-deep underline underline-offset-2"
            >
              {copied ? "Copiada" : "Copiar"}
            </button>
          </div>
        </div>
      )}
      {result && "error" in result && (
        <p className="max-w-[220px] text-right text-xs text-rosa">{result.error}</p>
      )}
    </div>
  );
}
UKT_RESET_PW_V9_EOF

echo "  - src/app/admin/page.tsx"
mkdir -p "src/app/admin"
cat > "src/app/admin/page.tsx" <<'UKT_RESET_PW_V9_EOF'
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
UKT_RESET_PW_V9_EOF


echo ""
echo "Archivos escritos. Creando commit..."
git add -A
git commit -m "Añade restablecer contraseña de un participante desde /admin

Botón junto a cada jugador con cuenta propia (no a los manuales): genera
una contraseña nueva al azar y la muestra una sola vez para pasársela,
sin guardarla nunca en texto plano."
git push

echo ""
echo "Archivos aplicados. No hace falta ninguna migración SQL esta vez."
