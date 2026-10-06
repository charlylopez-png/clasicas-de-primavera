// Bandera de la NACIONALIDAD de un corredor a partir de su código de país
// ISO de 2 letras (p. ej. "be"), guardado en special_event_riders.nationality.
// Se usa en Il Lombardia, donde los corredores se agrupan por equipo y el
// país va aparte. Las banderas son las de flag-icons (mismas que el Mundial).
const ISO_RE = /^[a-z]{2}$/i;

export function countryNameEs(iso: string | null | undefined): string | null {
  if (!iso || !ISO_RE.test(iso)) return null;
  try {
    return new Intl.DisplayNames(["es"], { type: "region" }).of(iso.toUpperCase()) ?? null;
  } catch {
    return null;
  }
}

export default function IsoFlag({
  iso,
  className = "",
}: {
  iso: string | null | undefined;
  className?: string;
}) {
  if (!iso || !ISO_RE.test(iso)) return null;
  return (
    <span
      className={`fi fi-${iso.toLowerCase()} rounded-[3px] align-[-1px] ${className}`}
      aria-hidden="true"
    />
  );
}
