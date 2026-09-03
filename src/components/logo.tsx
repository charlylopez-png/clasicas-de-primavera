// Wordmark "UKT" al estilo de los carteles de sectores de pavé de las
// clásicas (Paris–Roubaix, Ronde van Vlaanderen…): letras sólidas
// "fracturadas" en piezas, como si estuvieran hechas de adoquines.
// Por defecto usa --pill-text (se adapta solo entre modo claro y
// oscuro); pásale `color` para forzar un color fijo, por ejemplo sobre
// un fondo que no cambia con el tema (como el hero verde de portada).
export default function Logo({
  className,
  color = "var(--pill-text)",
}: {
  className?: string;
  color?: string;
}) {
  return (
    <svg viewBox="0 0 148 44" className={className} role="img" aria-label="UKT">
      <defs>
        <mask id="ukt-cuts" maskUnits="userSpaceOnUse" x="-10" y="-10" width="168" height="64">
          <rect x="-10" y="-10" width="168" height="64" fill="#fff" />
          <g stroke="#000" strokeWidth={2.6} strokeLinecap="butt">
            {/* U */}
            <line x1="4" y1="6" x2="18" y2="1" />
            <line x1="2" y1="20" x2="18" y2="16" />
            <line x1="6" y1="33" x2="20" y2="27" />
            {/* K */}
            <line x1="34" y1="4" x2="47" y2="14" />
            <line x1="30" y1="22" x2="46" y2="18" />
            <line x1="36" y1="26" x2="50" y2="38" />
            <line x1="34" y1="34" x2="46" y2="24" />
            {/* T */}
            <line x1="58" y1="8" x2="90" y2="4" />
            <line x1="68" y1="18" x2="78" y2="14" />
            <line x1="66" y1="30" x2="76" y2="26" />
            <line x1="70" y1="38" x2="80" y2="33" />
          </g>
        </mask>
      </defs>
      <text
        x="2"
        y="34"
        fontFamily="var(--font-display), 'Arial Narrow', sans-serif"
        fontWeight={700}
        fontSize={40}
        letterSpacing="-1"
        fill={color}
        mask="url(#ukt-cuts)"
      >
        UKT
      </text>
    </svg>
  );
}
