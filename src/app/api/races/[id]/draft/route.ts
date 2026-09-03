import { NextResponse } from "next/server";
import { z } from "zod";
import { sql, transaction } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { isValidSquad, SQUAD_SIZE, type RiderCategory } from "@/lib/riders";

const BodySchema = z.object({
  riderIds: z.array(z.string().uuid()).length(SQUAD_SIZE),
});

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "No autorizado." }, { status: 401 });
  }
  if (session.role !== "admin" && session.status !== "approved") {
    return NextResponse.json({ error: "Tu cuenta todavía no está aprobada." }, { status: 403 });
  }

  const { id: raceId } = await params;
  const race = await sql`select id from races where id = ${raceId}`;
  if (race.length === 0) {
    return NextResponse.json({ error: "Esa carrera no existe." }, { status: 404 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: `El fichaje debe tener exactamente ${SQUAD_SIZE} corredores.` },
      { status: 400 }
    );
  }

  const riderIds = Array.from(new Set(parsed.data.riderIds));
  if (riderIds.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Hay corredores repetidos en la selección." },
      { status: 400 }
    );
  }

  const rows = (await sql`
    select id, category from riders where id = any(${riderIds}::uuid[])
  `) as { id: string; category: RiderCategory }[];

  if (rows.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Alguno de los corredores seleccionados ya no existe." },
      { status: 400 }
    );
  }

  if (!isValidSquad(rows.map((r) => r.category))) {
    return NextResponse.json(
      { error: "El fichaje debe ser 1 Amarillo + 2 Rosas + 3 Verdes." },
      { status: 400 }
    );
  }

  await transaction([
    sql`delete from team_last_draft where user_id = ${session.userId} and race_id = ${raceId}`,
    sql`
      insert into team_last_draft (user_id, race_id, rider_id)
      select ${session.userId}::uuid, ${raceId}::uuid, unnest(${riderIds}::uuid[])
    `,
  ]);

  return NextResponse.json({ ok: true });
}
