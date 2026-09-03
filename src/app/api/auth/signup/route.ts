import { NextResponse } from "next/server";
import { z } from "zod";
import { sql } from "@/lib/db";
import { hashPassword, setSessionCookie } from "@/lib/auth";

const SignupSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8, "La contraseña debe tener al menos 8 caracteres."),
  displayName: z.string().min(2, "Dinos cómo te llamas.").max(60),
});

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = SignupSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: parsed.error.issues[0]?.message ?? "Datos inválidos." },
      { status: 400 }
    );
  }

  const { email, password, displayName } = parsed.data;
  const normalizedEmail = email.trim().toLowerCase();

  const existing = await sql`select id from users where email = ${normalizedEmail}`;
  if (existing.length > 0) {
    return NextResponse.json(
      { error: "Ya existe una cuenta con ese email." },
      { status: 409 }
    );
  }

  const passwordHash = await hashPassword(password);
  const adminEmail = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const isAdmin = adminEmail && normalizedEmail === adminEmail;

  const [user] = await sql`
    insert into users (email, password_hash, display_name, role, status)
    values (
      ${normalizedEmail},
      ${passwordHash},
      ${displayName.trim()},
      ${isAdmin ? "admin" : "participant"},
      ${isAdmin ? "approved" : "pending"}
    )
    returning id, email, display_name, role, status
  `;

  await setSessionCookie({
    userId: user.id,
    email: user.email,
    displayName: user.display_name,
    role: user.role,
    status: user.status,
    sanedrin: false,
  });

  return NextResponse.json({ ok: true, status: user.status });
}
