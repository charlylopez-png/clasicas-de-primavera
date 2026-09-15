import { countryIso } from "@/lib/mundial";

// Bandera real (imagen SVG vía la librería flag-icons) en vez de emoji:
// se ve igual en Windows, iPhone y Android, sin depender de que el
// sistema operativo tenga dibujos de bandera en su fuente de emoji.
export default function CountryFlag({
  team,
  className = "",
}: {
  team: string | null | undefined;
  className?: string;
}) {
  const iso = countryIso(team);
  if (!iso) return null;
  return (
    <span
      className={`fi fi-${iso} rounded-[3px] align-[-1px] ${className}`}
      aria-hidden="true"
    />
  );
}
