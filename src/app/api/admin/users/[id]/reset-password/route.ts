import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import { getSession, hashPassword, generateRandomPassword } from "@/lib/auth";

type UserRow = {
  id: string;
  is_manual: boolean;
};

// Genera una contraseña nueva para un participante y la devuelve en la
// respuesta — es la ÚNICA vez que se ve en texto plano; solo se guarda
// su hash. Pensado para cuando alguien ha olvidado la suya y no hay
// ("todavía) una pantalla de "olvidé mi contraseña" para que la pidan
// ellos mismos.
export async function POST(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const { id } = await params;
  const users = (await sql`
    select id, is_manual from users where id = ${id}
  `) as UserRow[];
  const user = users[0];
  if (!user) {
    return NextResponse.json({ error: "No se encuentra ese participante." }, { status: 404 });
  }
  if (user.is_manual) {
    return NextResponse.json(
      { error: "Este jugador es manual (no tiene cuenta propia): no hay contraseña que restablecer." },
      { status: 400 }
    );
  }

  const password = generateRandomPassword();
  const passwordHash = await hashPassword(password);
  await sql`update users set password_hash = ${passwordHash} where id = ${id}`;

  return NextResponse.json({ ok: true, password });
}
