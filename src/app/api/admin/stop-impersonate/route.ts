import { NextResponse } from "next/server";
import { stopImpersonation } from "@/lib/auth";

export async function POST() {
  const restored = await stopImpersonation();
  if (!restored) {
    return NextResponse.json(
      { error: "No había ninguna sesión de admin que restaurar." },
      { status: 400 }
    );
  }
  return NextResponse.json({ ok: true });
}
