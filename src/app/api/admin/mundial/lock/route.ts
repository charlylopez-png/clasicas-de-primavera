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
