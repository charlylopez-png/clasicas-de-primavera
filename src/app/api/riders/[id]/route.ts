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
