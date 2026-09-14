import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { CATEGORY_MULTIPLIER, MUNDIAL_SLUG } from "@/lib/mundial";

const BodySchema = z.object({
  name: z.string().trim().min(1).max(120),
  team: z.string().trim().max(120).optional().nullable(),
});

export async function POST(request: Request) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Nombre del corredor no válido." }, { status: 400 });
  }

  const events = await sql`select id from special_events where slug = ${MUNDIAL_SLUG}`;
  const eventId = events[0]?.id;
  if (!eventId) {
    return NextResponse.json({ error: "No se encuentra el evento del Mundial." }, { status: 500 });
  }

  const rows = await sql`
    insert into special_event_riders (event_id, name, team, category, multiplier)
    values (${eventId}, ${parsed.data.name}, ${parsed.data.team ?? null}, 'verde', ${CATEGORY_MULTIPLIER.verde})
    on conflict (event_id, name) do update set team = excluded.team
    returning id, name, team, category, multiplier
  `;

  return NextResponse.json({ ok: true, rider: rows[0] });
}
