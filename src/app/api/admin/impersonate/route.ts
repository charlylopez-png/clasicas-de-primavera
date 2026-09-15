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
