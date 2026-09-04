// Wordmark oficial "UKT" en Archivo Black, del sistema de identidad de
// la marca. Por defecto usa --pill-text; pásale `color` para forzar un
// color fijo, por ejemplo sobre un fondo que no cambia con el tema
// (como el hero de portada, con textura de adoquinado).
export default function Logo({
  className,
  color = "var(--pill-text)",
}: {
  className?: string;
  color?: string;
}) {
  return (
    <svg viewBox="0 0 900 300" className={className} role="img" aria-label="UKT">
      <text
        x="450"
        y="243"
        textAnchor="middle"
        fontFamily="var(--font-logo), 'Arial Black', sans-serif"
        fontSize={260}
        letterSpacing="-5"
        fill={color}
      >
        UKT
      </text>
    </svg>
  );
}
