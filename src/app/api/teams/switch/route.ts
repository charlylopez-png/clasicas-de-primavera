import { NextResponse } from "next/server";
import { z } from "zod";
import { getSession } from "@/lib/auth";
import { getUserTeams, setActiveTeamCookie } from "@/lib/teams";

const BodySchema = z.object({
  teamId: z.string().uuid(),
});

// Cambia cuál es el equipo "activo" (el que se edita en Equipo Base, Last
// Draft y Mundial) entre los del propio usuario de la sesión.
export async function POST(request: Request) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "No autorizado." }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Falta el equipo al que cambiar." }, { status: 400 });
  }

  const teams = await getUserTeams(session.userId);
  const team = teams.find((t) => t.id === parsed.data.teamId);
  if (!team) {
    return NextResponse.json({ error: "Ese equipo no es tuyo." }, { status: 403 });
  }

  await setActiveTeamCookie(team.id);
  return NextResponse.json({ ok: true });
}
