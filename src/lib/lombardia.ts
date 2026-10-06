import { sql } from "./db";
import {
  isPicksLocked,
  POINTS_BY_POSITION,
  pointsForPosition,
  countryIso,
  formatEventDate,
  type MundialEvent,
} from "./mundial";

export {
  isPicksLocked,
  POINTS_BY_POSITION,
  pointsForPosition,
  countryIso,
  formatEventDate,
};

// Il Lombardia 2026 reutiliza el mismo mecanismo que el Mundial y el Europeo
// (misma tabla special_events, misma tabla de puntos por puesto), pero con
// REGLAS PROPIAS de equipo, distintas de las otras pruebas: aparece una
// categoría nueva, ROJO (coeficiente 1,25), y el equipo pasa a ser de 7
// corredores: 1 Amarillo + 1 Rojo + 2 Rosas + 3 Verdes. Por eso las
// categorías, coeficientes, cupos y validación viven aquí y no se
// reexportan de lib/mundial.ts.
export type RiderCategory = "amarillo" | "rojo" | "rosa" | "verde";

export const CATEGORY_MULTIPLIER: Record<RiderCategory, number> = {
  amarillo: 1,
  rojo: 1.25,
  rosa: 1.5,
  verde: 2,
};

export const CATEGORY_LABEL: Record<RiderCategory, string> = {
  amarillo: "Amarillo",
  rojo: "Rojo",
  rosa: "Rosa",
  verde: "Verde",
};

export const SQUAD_REQUIREMENTS: Record<RiderCategory, number> = {
  amarillo: 1,
  rojo: 1,
  rosa: 2,
  verde: 3,
};
export const SQUAD_SIZE = 7;

export function squadCounts(categories: RiderCategory[]) {
  const counts: Record<RiderCategory, number> = {
    amarillo: 0,
    rojo: 0,
    rosa: 0,
    verde: 0,
  };
  for (const c of categories) counts[c]++;
  return counts;
}

export function isValidSquad(categories: RiderCategory[]) {
  if (categories.length !== SQUAD_SIZE) return false;
  const counts = squadCounts(categories);
  return (
    counts.amarillo === SQUAD_REQUIREMENTS.amarillo &&
    counts.rojo === SQUAD_REQUIREMENTS.rojo &&
    counts.rosa === SQUAD_REQUIREMENTS.rosa &&
    counts.verde === SQUAD_REQUIREMENTS.verde
  );
}

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
