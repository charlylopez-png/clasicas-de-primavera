import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { MUNDIAL_SLUG } from "@/lib/mundial";

// Deja al admin quitar el fichaje de un equipo para el Mundial. Como
// "teams" es la misma entidad que usan las clásicas (un jugador puede usar
// el mismo equipo en clásicas y Mundial a la vez desde la v7), esto NUNCA
// borra el equipo entero de golpe: solo quita sus corredores fichados para
// esta prueba. Si, después de eso, ese equipo no tiene ni Equipo Base ni
// Last Draft ni fichajes de ningún otro evento especial, se considera que
// era un equipo solo para el Mundial y se borra también, para no dejar un
// equipo vacío colgando en el selector del jugador.
export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ teamId: string }> }
) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const { teamId } = await params;

  const events = await sql`select id from special_events where slug = ${MUNDIAL_SLUG}`;
  const eventId = events[0]?.id;
  if (!eventId) {
    return NextResponse.json({ error: "No se encuentra el evento del Mundial." }, { status: 500 });
  }

  const deleted = await sql`
    delete from special_event_picks where event_id = ${eventId} and team_id = ${teamId}
    returning rider_id
  `;
  if (deleted.length === 0) {
    return NextResponse.json(
      { error: "Ese equipo no tiene fichajes para el Mundial." },
      { status: 404 }
    );
  }

  const remaining = await sql`
    select
      (select count(*) from team_base where team_id = ${teamId}) as base_count,
      (select count(*) from team_last_draft where team_id = ${teamId}) as draft_count,
      (select count(*) from special_event_picks where team_id = ${teamId}) as picks_count
  `;
  const { base_count, draft_count, picks_count } = remaining[0] as {
    base_count: string;
    draft_count: string;
    picks_count: string;
  };
  let teamDeleted = false;
  if (Number(base_count) === 0 && Number(draft_count) === 0 && Number(picks_count) === 0) {
    await sql`delete from teams where id = ${teamId}`;
    teamDeleted = true;
  }

  return NextResponse.json({ ok: true, teamDeleted });
}
