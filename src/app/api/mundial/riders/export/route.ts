import { NextResponse } from "next/server";
import { sql } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { CATEGORY_LABEL, MUNDIAL_SLUG, type RiderCategory } from "@/lib/mundial";

// Orden de categoría en el CSV (no alfabético): Amarillo, Rosa, Verde.
const CATEGORY_ORDER: RiderCategory[] = ["amarillo", "rosa", "verde"];

function csvEscape(value: string): string {
  if (/[";\n]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

export async function GET() {
  const session = await getSession();
  if (!session || session.role !== "admin") {
    return NextResponse.json({ error: "No autorizado." }, { status: 403 });
  }

  const events = await sql`select id from special_events where slug = ${MUNDIAL_SLUG}`;
  const eventId = events[0]?.id;
  if (!eventId) {
    return NextResponse.json({ error: "No se encuentra el evento del Mundial." }, { status: 500 });
  }

  const rows = (await sql`
    select name, team, category
    from special_event_riders
    where event_id = ${eventId}
  `) as { name: string; team: string | null; category: RiderCategory }[];

  // Agrupado primero por categoría y, dentro, por país — así se ve de un
  // vistazo cada bloque de color; en Excel se puede reordenar por la
  // columna País con un clic si se prefiere esa agrupación.
  rows.sort((a, b) => {
    const catDiff = CATEGORY_ORDER.indexOf(a.category) - CATEGORY_ORDER.indexOf(b.category);
    if (catDiff !== 0) return catDiff;
    const teamDiff = (a.team ?? "").localeCompare(b.team ?? "", "es");
    if (teamDiff !== 0) return teamDiff;
    return a.name.localeCompare(b.name, "es");
  });

  const lines = [["Categoría", "País", "Corredor"].join(";")];
  for (const r of rows) {
    lines.push(
      [csvEscape(CATEGORY_LABEL[r.category]), csvEscape(r.team ?? ""), csvEscape(r.name)].join(";")
    );
  }
  // BOM para que Excel detecte UTF-8 y no rompa los acentos/ñ; ";" como
  // separador porque en Excel con configuración regional española la coma
  // es el separador decimal.
  const csv = "﻿" + lines.join("\r\n") + "\r\n";

  return new NextResponse(csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": 'attachment; filename="mundial-corredores.csv"',
    },
  });
}
