import { NextResponse } from "next/server";
import { z } from "zod";
import { sql, transaction } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { getActiveTeam, renameTeam, DuplicateTeamNameError } from "@/lib/teams";
import { isValidSquad, SQUAD_SIZE, MUNDIAL_SLUG, type RiderCategory } from "@/lib/mundial";

const BodySchema = z.object({
  riderIds: z.array(z.string().uuid()).length(SQUAD_SIZE),
  teamName: z.string().trim().min(1).max(60),
});

export async function POST(request: Request) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "No autorizado." }, { status: 401 });
  }
  if (session.role !== "admin" && session.status !== "approved") {
    return NextResponse.json({ error: "Tu cuenta todavía no está aprobada." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      {
        error: `Ponle un nombre a tu equipo y elige exactamente ${SQUAD_SIZE} corredores.`,
      },
      { status: 400 }
    );
  }

  const events = await sql`
    select id, picks_lock_at from special_events where slug = ${MUNDIAL_SLUG}
  `;
  const event = events[0];
  if (!event) {
    return NextResponse.json({ error: "No se encuentra el evento del Mundial." }, { status: 500 });
  }
  if (event.picks_lock_at && new Date(event.picks_lock_at).getTime() <= Date.now()) {
    return NextResponse.json(
      { error: "Los fichajes para el Mundial ya están cerrados." },
      { status: 403 }
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
    select id, category from special_event_riders
    where event_id = ${event.id} and id = any(${riderIds}::uuid[])
  `) as { id: string; category: RiderCategory }[];

  if (rows.length !== SQUAD_SIZE) {
    return NextResponse.json(
      { error: "Alguno de los corredores seleccionados ya no existe." },
      { status: 400 }
    );
  }

  if (!isValidSquad(rows.map((r) => r.category))) {
    return NextResponse.json(
      { error: "El equipo debe ser 1 Amarillo + 2 Rosas + 3 Verdes." },
      { status: 400 }
    );
  }

  const { activeTeam } = await getActiveTeam(session.userId);

  try {
    await renameTeam(activeTeam.id, session.userId, parsed.data.teamName);
  } catch (err) {
    if (err instanceof DuplicateTeamNameError) {
      return NextResponse.json({ error: err.message }, { status: 409 });
    }
    throw err;
  }

  await transaction([
    sql`delete from special_event_picks where event_id = ${event.id} and team_id = ${activeTeam.id}`,
    sql`
      insert into special_event_picks (event_id, team_id, rider_id)
      select ${event.id}::uuid, ${activeTeam.id}::uuid, unnest(${riderIds}::uuid[])
    `,
  ]);

  return NextResponse.json({ ok: true });
}
