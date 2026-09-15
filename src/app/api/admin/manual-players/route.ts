import { NextResponse } from "next/server";
import { randomUUID } from "crypto";
import { z } from "zod";
import { sql } from "@/lib/db";
import { getSession, hashPassword } from "@/lib/auth";

const BodySchema = z.object({
  displayName: z.string().trim().min(1).max(60),
});

// Jugadores "manuales": gente que no usa la app (mayores con dificultades
// con la tecnología, por ejemplo) a los que el admin quiere apuntar de
// todas formas — tanto a las clásicas como al Mundial. Se guardan como
// una fila más de `users`, con is_manual = true y una contraseña al azar
// que nunca se entrega a nadie, así que en la práctica no pueden iniciar
// sesión (y el login además los rechaza explícitamente por si acaso). El
// admin actúa por ellos entrando en su nombre con "Actuar como" desde
// /admin — así hace exactamente los mismos pasos que haría cualquier
// jugador (Equipo Base, Last Draft, elección del Mundial…), sin tener que
// duplicar cada pantalla.
export async function POST(request: Request) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const body = await request.json().catch(() => null);
  const parsed = BodySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: "Ponle un nombre al jugador." }, { status: 400 });
  }

  const placeholderEmail = `manual-${randomUUID()}@ukt.invalid`;
  const unusablePassword = await hashPassword(randomUUID());

  const rows = await sql`
    insert into users (email, password_hash, display_name, role, status, is_manual)
    values (${placeholderEmail}, ${unusablePassword}, ${parsed.data.displayName}, 'participant', 'approved', true)
    returning id, display_name
  `;

  return NextResponse.json({
    ok: true,
    player: { id: rows[0].id, displayName: rows[0].display_name },
  });
}
