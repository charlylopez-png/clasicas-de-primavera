import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { CATEGORY_MULTIPLIER } from "@/lib/mundial";

const PatchSchema = z.object({
  category: z.enum(["amarillo", "rosa", "verde"]),
});

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
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
    update special_event_riders
    set category = ${parsed.data.category}, multiplier = ${multiplier}
    where id = ${id}
  `;

  return NextResponse.json({ ok: true, category: parsed.data.category, multiplier });
}

export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const { id } = await params;
  await sql`delete from special_event_riders where id = ${id}`;

  return NextResponse.json({ ok: true });
}
