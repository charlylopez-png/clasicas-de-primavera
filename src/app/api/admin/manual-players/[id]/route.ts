import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";

// Solo borra si is_manual = true, para que este endpoint no pueda usarse
// nunca para eliminar una cuenta real por error. El borrado en cascada ya
// existente (special_event_picks/squads referencian users con ON DELETE
// CASCADE) limpia también su ficha y su equipo del Mundial.
export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const { id } = await params;
  const rows = await sql`
    delete from users where id = ${id} and is_manual = true
    returning id
  `;
  if (!rows[0]) {
    return NextResponse.json(
      { error: "No se encuentra ese jugador manual." },
      { status: 404 }
    );
  }

  return NextResponse.json({ ok: true });
}
