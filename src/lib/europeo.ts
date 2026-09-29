import { sql } from "./db";
import type { RiderCategory } from "./riders";
export type { RiderCategory };

// El Europeo de Ljubljana 2026 reutiliza exactamente el mismo mecanismo que
// el Mundial de Montreal (misma tabla special_events, mismas reglas de
// fichaje 1 Amarillo + 2 Rosas + 3 Verdes, misma tabla de puntos por
// puesto): por eso este fichero reexporta de lib/mundial.ts todo lo que es
// genérico (categorías, puntos, banderas, formateo de fecha) en vez de
// duplicarlo, y solo añade lo específico de este evento — el slug y cómo
// encontrarlo en la base de datos.
import {
  isPicksLocked,
  CATEGORY_MULTIPLIER,
  CATEGORY_LABEL,
  SQUAD_REQUIREMENTS,
  SQUAD_SIZE,
  squadCounts,
  isValidSquad,
  POINTS_BY_POSITION,
  pointsForPosition,
  countryIso,
  formatEventDate,
  type MundialEvent,
} from "./mundial";

export {
  isPicksLocked,
  CATEGORY_MULTIPLIER,
  CATEGORY_LABEL,
  SQUAD_REQUIREMENTS,
  SQUAD_SIZE,
  squadCounts,
  isValidSquad,
  POINTS_BY_POSITION,
  pointsForPosition,
  countryIso,
  formatEventDate,
};

export const EUROPEO_SLUG = "europeo-ljubljana-2026";

// Misma forma que el evento del Mundial (id, name, event_date, picks_lock_at).
export type EuropeoEvent = MundialEvent;

// Usado por todas las páginas de /europeo/*: evita repetir la misma
// consulta en cada page.tsx.
export async function getEuropeoEvent(): Promise<EuropeoEvent | null> {
  const events = (await sql`
    select id, name, event_date, picks_lock_at
    from special_events where slug = ${EUROPEO_SLUG}
  `) as EuropeoEvent[];
  return events[0] ?? null;
}
