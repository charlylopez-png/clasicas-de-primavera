import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { CATEGORY_MULTIPLIER, type RiderCategory } from "@/lib/mundial";

// Todos los campos son opcionales para poder reutilizar el mismo PATCH
// tanto para el cambio rápido de color (solo category) como para la
// edición de nombre/país (name/team) — pero hace falta al menos uno.
const PatchSchema = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  team: z.string().trim().max(120).nullable().optional(),
  category: z.enum(["amarillo", "rosa", "verde"]).optional(),
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
  if (
    !parsed.success ||
    (parsed.data.name === undefined &&
      parsed.data.team === undefined &&
      parsed.data.category === undefined)
  ) {
    return NextResponse.json({ error: "Nada que actualizar." }, { status: 400 });
  }

  const current = await sql`
    select name, team, category from special_event_riders where id = ${id}
  `;
  if (!current[0]) {
    return NextResponse.json({ error: "Corredor no encontrado." }, { status: 404 });
  }

  const name = parsed.data.name ?? (current[0].name as string);
  const team = parsed.data.team !== undefined ? parsed.data.team : (current[0].team as string | null);
  const category = (parsed.data.category ?? current[0].category) as RiderCategory;
  const multiplier = CATEGORY_MULTIPLIER[category];

  try {
    await sql`
      update special_event_riders
      set name = ${name}, team = ${team}, category = ${category}, multiplier = ${multiplier}
      where id = ${id}
    `;
  } catch {
    return NextResponse.json(
      { error: "Ya existe un corredor con ese nombre en esta prueba." },
      { status: 400 }
    );
  }

  return NextResponse.json({ ok: true, name, team, category, multiplier });
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
