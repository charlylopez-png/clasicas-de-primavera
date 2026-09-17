#!/usr/bin/env bash
set -euo pipefail

# apply-mundial-lock-v11.sh — añade, solo para el admin, un botón "Cambiar
# día de cierre" en la cabecera del Mundial para modificar (o quitar) el
# momento en que se bloquean los fichajes, sin tener que tocar la base de
# datos a mano. El resto de jugadores no ve ningún control nuevo, solo
# sigue viendo el aviso de "Fichajes abiertos hasta..." de siempre.
#
# No hace falta ninguna migración SQL: la columna picks_lock_at ya existe
# en la tabla special_events desde el principio del Mundial.
#
# Ejecuta esto DESDE LA RAÍZ del repo (donde está db/schema.sql), con el
# Codespace ya abierto.

if [ ! -f "db/schema.sql" ]; then
  echo "Error: no se encuentra db/schema.sql en el directorio actual."
  echo "Ejecuta este script desde la raíz del repo clasicas-de-primavera."
  exit 1
fi

echo "Aplicando cambio de día de cierre del Mundial desde /mundial (v11)..."

echo "  - src/app/api/admin/mundial/lock/route.ts"
mkdir -p "src/app/api/admin/mundial/lock"
cat > "src/app/api/admin/mundial/lock/route.ts" <<'UKT_MUNDIAL_LOCK_V11_EOF'
import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { MUNDIAL_SLUG } from "@/lib/mundial";

// Deja al admin cambiar (o quitar) el momento de cierre de fichajes del
// Mundial desde la propia app, sin tener que tocar la base de datos a
// mano cada vez que cambie la fecha.
const BodySchema = z.object({
  picksLockAt: z.string().min(1).nullable(),
});

export async function POST(request: Request) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Fecha no válida." }, { status: 400 });
  }

  let newLockAt: Date | null = null;
  if (parsed.data.picksLockAt) {
    newLockAt = new Date(parsed.data.picksLockAt);
    if (Number.isNaN(newLockAt.getTime())) {
      return NextResponse.json({ error: "Fecha no válida." }, { status: 400 });
    }
  }

  const newLockAtIso = newLockAt ? newLockAt.toISOString() : null;

  const result = await sql`
    update special_events
    set picks_lock_at = ${newLockAtIso}::timestamptz
    where slug = ${MUNDIAL_SLUG}
    returning id
  `;
  if (result.length === 0) {
    return NextResponse.json({ error: "No se encuentra el evento del Mundial." }, { status: 500 });
  }

  return NextResponse.json({ ok: true, picksLockAt: newLockAtIso });
}
UKT_MUNDIAL_LOCK_V11_EOF

echo "  - src/components/mundial-lock-editor.tsx"
mkdir -p "src/components"
cat > "src/components/mundial-lock-editor.tsx" <<'UKT_MUNDIAL_LOCK_V11_EOF'
"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { formatEventDate } from "@/lib/mundial";

function toLocalInputValue(value: string | Date): string {
  const d = value instanceof Date ? value : new Date(value);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(
    d.getHours()
  )}:${pad(d.getMinutes())}`;
}

// Solo para el admin: deja cambiar (o quitar) el momento de cierre de
// fichajes del Mundial desde la propia app, en la hora del dispositivo
// desde el que se edite (pensado para usarse desde España).
export default function MundialLockEditor({
  picksLockAt,
}: {
  picksLockAt: string | Date | null;
}) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(() =>
    picksLockAt ? toLocalInputValue(picksLockAt) : ""
  );
  const [error, setError] = useState<string | null>(null);

  function save(newValue: string | null) {
    setError(null);
    startTransition(async () => {
      const res = await fetch("/api/admin/mundial/lock", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ picksLockAt: newValue }),
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setError(data?.error ?? "No se pudo guardar.");
        return;
      }
      setEditing(false);
      router.refresh();
    });
  }

  if (!editing) {
    return (
      <div className="mt-2 flex flex-wrap items-center gap-2">
        <p className="text-xs text-text-soft">
          {picksLockAt
            ? `Cierre configurado: ${formatEventDate(picksLockAt)}.`
            : "Sin fecha de cierre configurada — los fichajes no se bloquean nunca."}
        </p>
        <button
          type="button"
          onClick={() => {
            setValue(picksLockAt ? toLocalInputValue(picksLockAt) : "");
            setEditing(true);
          }}
          className="rounded-full border border-dashed border-line px-3 py-1.5 text-xs text-verde-deep hover:border-verde-deep"
        >
          Cambiar día de cierre
        </button>
      </div>
    );
  }

  return (
    <div className="mt-2 flex flex-col items-start gap-2 rounded-xl border border-line bg-surface p-3">
      <label className="text-xs text-text-soft">
        Fichajes cerrados a partir de (hora de este dispositivo):
      </label>
      <div className="flex w-full flex-wrap items-center gap-2">
        <input
          type="datetime-local"
          value={value}
          onChange={(e) => setValue(e.target.value)}
          className="min-w-0 flex-1 rounded-full border border-line bg-surface px-3 py-2 text-sm outline-none focus:border-verde"
        />
        <button
          type="button"
          disabled={!value || isPending}
          onClick={() => save(value)}
          className="rounded-full bg-amarillo px-3.5 py-2 text-sm font-semibold text-on-accent disabled:opacity-40"
        >
          {isPending ? "Guardando…" : "Guardar"}
        </button>
        <button
          type="button"
          disabled={isPending}
          onClick={() => setEditing(false)}
          className="rounded-full px-2.5 py-2 text-sm text-text-soft underline underline-offset-2"
        >
          Cancelar
        </button>
      </div>
      <button
        type="button"
        disabled={isPending}
        onClick={() => save(null)}
        className="text-xs text-rosa underline underline-offset-2"
      >
        Quitar cierre (dejar fichajes siempre abiertos)
      </button>
      {error && <p className="text-xs text-rosa">{error}</p>}
    </div>
  );
}
UKT_MUNDIAL_LOCK_V11_EOF

echo "  - src/app/mundial/layout.tsx"
mkdir -p "src/app/mundial"
cat > "src/app/mundial/layout.tsx" <<'UKT_MUNDIAL_LOCK_V11_EOF'
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
UKT_MUNDIAL_LOCK_V11_EOF


echo ""
echo "Archivos escritos. Creando commit..."
git add -A
git commit -m "Permite al admin cambiar el día de cierre de fichajes del Mundial

Botón \"Cambiar día de cierre\" visible solo para el admin en la cabecera
de /mundial: deja fijar una nueva fecha y hora de cierre, o quitarla del
todo, sin tocar la base de datos a mano."
git push

echo ""
echo "Archivos aplicados. No hace falta ninguna migración SQL esta vez."
