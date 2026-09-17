import { NextResponse } from "next/server";
import { z } from "zod";
import { getSession } from "@/lib/auth";
import {
  createTeam,
  setActiveTeamCookie,
  DuplicateTeamNameError,
  TEAM_NAME_MAX_LEN,
} from "@/lib/teams";

const BodySchema = z.object({
  name: z.string().trim().min(1).max(TEAM_NAME_MAX_LEN),
});

// Crea un nuevo equipo para el usuario de la sesión actual (o, con
// "Actuar como", para el jugador suplantado) y lo deja como equipo
// activo. No hay límite de equipos por jugador.
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
      { error: "Ponle un nombre al equipo (máximo 60 caracteres)." },
      { status: 400 }
    );
  }

  try {
    const team = await createTeam(session.userId, parsed.data.name);
    await setActiveTeamCookie(team.id);
    return NextResponse.json({ ok: true, team });
  } catch (err) {
    if (err instanceof DuplicateTeamNameError) {
      return NextResponse.json({ error: err.message }, { status: 409 });
    }
    throw err;
  }
}
