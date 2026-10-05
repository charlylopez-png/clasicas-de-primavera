import { sql } from "./db";
import type { RiderCategory } from "./riders";
export type { RiderCategory };

// Il Lombardia 2026 reutiliza exactamente el mismo mecanismo que
// el Mundial de Montreal y el Europeo (misma tabla special_events, mismas reglas de
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

export const LOMBARDIA_SLUG = "il-lombardia-2026";

// Misma forma que el evento del Mundial (id, name, event_date, picks_lock_at).
export type LombardiaEvent = MundialEvent;

// Usado por todas las páginas de /lombardia/*: evita repetir la misma
// consulta en cada page.tsx.
export async function getLombardiaEvent(): Promise<LombardiaEvent | null> {
  const events = (await sql`
    select id, name, event_date, picks_lock_at
    from special_events where slug = ${LOMBARDIA_SLUG}
  `) as LombardiaEvent[];
  return events[0] ?? null;
}
