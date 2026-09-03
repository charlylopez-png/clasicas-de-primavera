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
