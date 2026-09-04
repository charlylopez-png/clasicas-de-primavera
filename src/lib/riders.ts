export type RiderCategory = "amarillo" | "rosa" | "verde";

// Debe coincidir siempre con las CategoryCard de /reglamento.
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

// Composición fija de cualquier bloque de 6 (Equipo Base o Last Draft de
// una carrera): 1 Amarillo + 2 Rosas + 3 Verdes.
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

const MONTHS_ES_LONG = [
  "enero", "febrero", "marzo", "abril", "mayo", "junio",
  "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre",
];
const MONTHS_ES_SHORT = [
  "ene", "feb", "mar", "abr", "may", "jun",
  "jul", "ago", "sep", "oct", "nov", "dic",
];

// Formatea una fecha de carrera sin desplazamientos de zona horaria. La
// columna `race_date` es un `date` de Postgres: según la versión del
// driver puede llegar como string "YYYY-MM-DD" o ya como objeto Date (en
// cuyo caso usamos los getters UTC, porque un `date` sin hora se
// interpreta en UTC y los getters locales podrían restar/sumar un día
// según la zona horaria del servidor).
export function formatRaceDate(
  value: string | Date,
  style: "long" | "short" = "long"
) {
  let year: number;
  let month: number; // 1-12
  let day: number;
  if (value instanceof Date) {
    year = value.getUTCFullYear();
    month = value.getUTCMonth() + 1;
    day = value.getUTCDate();
  } else {
    [year, month, day] = value.split("-").map(Number);
  }
  if (style === "short") return `${day} ${MONTHS_ES_SHORT[month - 1]} ${year}`;
  return `${day} de ${MONTHS_ES_LONG[month - 1]} de ${year}`;
}

// Los valores numeric de Postgres llegan como string; formatea "1.5" como
// se ve en toda la app: "×1,5".
export function formatCoefficient(value: string | number) {
  const num = typeof value === "string" ? Number(value) : value;
  const text = Number.isInteger(num) ? String(num) : String(num).replace(".", ",");
  return `×${text}`;
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
