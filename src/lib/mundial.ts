import { sql } from "./db";
import type { RiderCategory } from "./riders";
export type { RiderCategory };

// Todo lo de este fichero es deliberadamente independiente de lib/riders.ts:
// el Mundial de Montreal es una prueba única y separada de la porra de
// clásicas (mismo login, misma web, pero ni corredores ni puntuación se
// mezclan con la general).

export const MUNDIAL_SLUG = "montreal-2026";

export type MundialEvent = {
  id: string;
  name: string;
  event_date: string | Date | null;
  picks_lock_at: string | Date | null;
};

// Usado por todas las páginas de /mundial/*: evita repetir la misma
// consulta en cada page.tsx.
export async function getMundialEvent(): Promise<MundialEvent | null> {
  const events = (await sql`
    select id, name, event_date, picks_lock_at
    from special_events where slug = ${MUNDIAL_SLUG}
  `) as MundialEvent[];
  return events[0] ?? null;
}

export function isPicksLocked(picksLockAt: string | Date | null) {
  if (!picksLockAt) return false;
  return new Date(picksLockAt).getTime() <= Date.now();
}

export const CATEGORY_MULTIPLIER: Record<RiderCategory, number> = {
  amarillo: 1,
  rosa: 1.5,
  verde: 2,
};

export const CATEGORY_LABEL: Record<RiderCategory, string> = {
  amarillo: "Amarillo",
  rosa: "Rosa",
  verde: "Verde",
};

// Misma composición que Equipo Base / Last Draft: 1 Amarillo + 2 Rosas + 3
// Verdes = 6 corredores.
export const SQUAD_REQUIREMENTS: Record<RiderCategory, number> = {
  amarillo: 1,
  rosa: 2,
  verde: 3,
};
export const SQUAD_SIZE = 6;

export function squadCounts(categories: RiderCategory[]) {
  const counts: Record<RiderCategory, number> = { amarillo: 0, rosa: 0, verde: 0 };
  for (const c of categories) counts[c]++;
  return counts;
}

export function isValidSquad(categories: RiderCategory[]) {
  if (categories.length !== SQUAD_SIZE) return false;
  const counts = squadCounts(categories);
  return (
    counts.amarillo === SQUAD_REQUIREMENTS.amarillo &&
    counts.rosa === SQUAD_REQUIREMENTS.rosa &&
    counts.verde === SQUAD_REQUIREMENTS.verde
  );
}

// Misma tabla de puntos por puesto que las clásicas (1º-20º).
export const POINTS_BY_POSITION: Record<number, number> = {
  1: 100, 2: 50, 3: 30, 4: 20, 5: 16, 6: 15, 7: 14, 8: 13, 9: 12, 10: 11,
  11: 10, 12: 9, 13: 8, 14: 7, 15: 6, 16: 5, 17: 4, 18: 3, 19: 2, 20: 1,
};

export function pointsForPosition(position: number | null | undefined) {
  if (!position) return 0;
  return POINTS_BY_POSITION[position] ?? 0;
}

// País (tal como se guarda en special_event_riders.team, en español) →
// código ISO 3166-1 alfa-2, para pintar la bandera antes del nombre. Los
// dos casos sin código real (atletas neutrales y el Equipo de Refugiados)
// se quedan sin bandera a propósito.
const COUNTRY_ISO: Record<string, string> = {
  Argelia: "DZ",
  Australia: "AU",
  Austria: "AT",
  Bélgica: "BE",
  Bermudas: "BM",
  Belice: "BZ",
  Brasil: "BR",
  Canadá: "CA",
  Chile: "CL",
  China: "CN",
  Colombia: "CO",
  "Costa Rica": "CR",
  Chipre: "CY",
  Chequia: "CZ",
  Dinamarca: "DK",
  Dominica: "DM",
  Ecuador: "EC",
  Eritrea: "ER",
  España: "ES",
  Estonia: "EE",
  Francia: "FR",
  "Gran Bretaña": "GB",
  "Guinea-Bisáu": "GW",
  Alemania: "DE",
  Grecia: "GR",
  Guatemala: "GT",
  Honduras: "HN",
  Hungría: "HU",
  Irlanda: "IE",
  Israel: "IL",
  Italia: "IT",
  Japón: "JP",
  Kazajistán: "KZ",
  "Arabia Saudí": "SA",
  Letonia: "LV",
  Luxemburgo: "LU",
  México: "MX",
  Mongolia: "MN",
  Mónaco: "MC",
  Mauricio: "MU",
  "Países Bajos": "NL",
  Noruega: "NO",
  "Nueva Zelanda": "NZ",
  Panamá: "PA",
  Polonia: "PL",
  Portugal: "PT",
  Rumanía: "RO",
  Sudáfrica: "ZA",
  Eslovenia: "SI",
  Serbia: "RS",
  Suiza: "CH",
  Eslovaquia: "SK",
  Suecia: "SE",
  Tailandia: "TH",
  Ucrania: "UA",
  Uruguay: "UY",
  "Estados Unidos": "US",
  Uzbekistán: "UZ",
  Venezuela: "VE",
};

function isoToFlagEmoji(iso: string) {
  return String.fromCodePoint(
    ...iso
      .toUpperCase()
      .split("")
      .map((c) => 127397 + c.charCodeAt(0))
  );
}

export function countryFlag(team: string | null | undefined): string {
  if (!team) return "";
  const iso = COUNTRY_ISO[team.trim()];
  return iso ? isoToFlagEmoji(iso) : "";
}

export function formatEventDate(value: string | Date) {
  let year: number;
  let month: number;
  let day: number;
  if (value instanceof Date) {
    year = value.getUTCFullYear();
    month = value.getUTCMonth() + 1;
    day = value.getUTCDate();
  } else {
    [year, month, day] = value.split("-").map(Number);
  }
  const MONTHS = [
    "enero", "febrero", "marzo", "abril", "mayo", "junio",
    "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
  ];
  return `${day} de ${MONTHS[month - 1]} de ${year}`;
}
