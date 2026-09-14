import { NextResponse } from "next/server";
import { z } from "zod";
import { sql, transaction } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { MUNDIAL_SLUG } from "@/lib/mundial";

// Una fila por corredor de la lista cerrada que acabó en el top 20;
// position: null borra su resultado (no puntuó / no acabó la carrera).
const BodySchema = z.object({
  results: z.array(
    z.object({
      riderId: z.string().uuid(),
      position: z.number().int().min(1).max(20).nullable(),
    })
  ),
});

export async function POST(request: Request) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Datos de resultados no válidos." }, { status: 400 });
  }

  const events = await sql`select id from special_events where slug = ${MUNDIAL_SLUG}`;
  const eventId = events[0]?.id;
  if (!eventId) {
    return NextResponse.json({ error: "No se encuentra el evento del Mundial." }, { status: 500 });
  }

  // Dos puestos no pueden repetirse: comprobamos duplicados antes de guardar.
  const positions = parsed.data.results
    .map((r) => r.position)
    .filter((p): p is number => p !== null);
  if (new Set(positions).size !== positions.length) {
    return NextResponse.json(
      { error: "Hay un puesto repetido entre dos corredores distintos." },
      { status: 400 }
    );
  }

  const queries = parsed.data.results.map((r) =>
    r.position === null
      ? sql`
          delete from special_event_results
          where event_id = ${eventId} and rider_id = ${r.riderId}
        `
      : sql`
          insert into special_event_results (event_id, rider_id, position)
          values (${eventId}, ${r.riderId}, ${r.position})
          on conflict (event_id, rider_id) do update set position = excluded.position
        `
  );

  await transaction(queries);

  return NextResponse.json({ ok: true });
}
