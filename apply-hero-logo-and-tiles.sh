#!/usr/bin/env bash
set -e

if [ ! -f db/schema.sql ]; then
  echo "ERROR: no encuentro db/schema.sql en esta carpeta."
  echo "Asegurate de estar en la raiz del repo clasicas-de-primavera antes de ejecutar este script."
  exit 1
fi

mkdir -p src/components src/app

cat > src/components/logo.tsx << 'EOF'
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
EOF

cat > src/app/page.tsx << 'EOF'
import Link from "next/link";
import Logo from "@/components/logo";

export default function Home() {
  return (
    <>
      <section
        className="px-5 py-14 text-[var(--hero-text)] sm:py-20"
        style={{
          background:
            "linear-gradient(165deg, var(--hero-bg-1), var(--hero-bg-2) 130%)",
        }}
      >
        <div className="mx-auto max-w-3xl">
          <span className="inline-block rounded-full border border-white/40 px-3 py-1 font-display text-[11px] uppercase tracking-[0.16em]">
            Reglamento oficial · 2027
          </span>
          <h1 className="mt-5">
            <Logo
              className="h-16 w-auto sm:h-20"
              color="var(--hero-text)"
            />
          </h1>
          <div className="mt-3 font-display text-sm uppercase tracking-wide text-amarillo">
            Udaberriko Klasiko Txirrindulariak
          </div>
          <p className="mt-1 font-display text-xl normal-case">
            La porra de las Clásicas de Primavera
          </p>
          <p className="mt-5 max-w-xl border-l-2 border-amarillo pl-4 text-sm leading-relaxed text-white/90">
            Doce clásicas del World Tour, de finales de febrero a finales de
            abril. Elige tu equipo, sigue el calendario y pelea la general con
            la cuadrilla.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link
              href="/signup"
              className="rounded-full bg-amarillo px-5 py-2.5 font-display text-xs uppercase tracking-wide text-[#2b2103]"
            >
              Apuntarme a la porra
            </Link>
            <Link
              href="/reglamento"
              className="rounded-full border border-white/40 px-5 py-2.5 font-display text-xs uppercase tracking-wide text-white"
            >
              Ver el reglamento
            </Link>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-3xl px-5 py-12">
        <div className="grid gap-4 sm:grid-cols-3">
          <InfoCard n="12" label="Carreras" />
          <InfoCard n="12" label="Corredores por equipo" />
          <InfoCard n="1" label="Duelo Sprint por carrera" />
        </div>
      </section>
    </>
  );
}

function InfoCard({ n, label }: { n: string; label: string }) {
  return (
    <div className="rounded-xl border border-line bg-surface px-4 py-5 text-center">
      <div className="font-display text-3xl font-bold text-verde">{n}</div>
      <div className="mt-1 text-[11px] uppercase tracking-wide text-text-soft">
        {label}
      </div>
    </div>
  );
}
EOF

cat > src/app/calendario/page.tsx << 'EOF'
import Image from "next/image";

type Race = {
  order: number;
  name: string;
  stars: number;
  multiplier: string;
  logo: string;
  darkTile?: boolean;
};

const RACES: Race[] = [
  { order: 1, name: "Omloop Het Nieuwsblad", stars: 3, multiplier: "×1,5", logo: "/logos/01-omloop-het-nieuwsblad.jpg" },
  { order: 2, name: "Strade Bianche", stars: 4, multiplier: "×1,75", logo: "/logos/02-strade-bianche.png" },
  { order: 3, name: "Milano–Sanremo", stars: 5, multiplier: "×2", logo: "/logos/03-milano-sanremo.png" },
  { order: 4, name: "Ronde van Brugge", stars: 2, multiplier: "×1", logo: "/logos/04-ronde-van-brugge.jpg" },
  { order: 5, name: "E3 Saxo Classic", stars: 3, multiplier: "×1,5", logo: "/logos/05-e3-saxo-classic.png" },
  { order: 6, name: "In Flanders Fields", stars: 2, multiplier: "×1", logo: "/logos/06-gent-wevelgem-in-flanders-fields.png" },
  { order: 7, name: "Dwars door Vlaanderen", stars: 2, multiplier: "×1", logo: "/logos/07-dwars-door-vlaanderen.png" },
  { order: 8, name: "Ronde van Vlaanderen", stars: 5, multiplier: "×2", logo: "/logos/08-ronde-van-vlaanderen.png" },
  { order: 9, name: "Paris–Roubaix", stars: 5, multiplier: "×2", logo: "/logos/09-paris-roubaix.png", darkTile: true },
  { order: 10, name: "Amstel Gold Race", stars: 3, multiplier: "×1,5", logo: "/logos/10-amstel-gold-race.png" },
  { order: 11, name: "La Flèche Wallonne", stars: 3, multiplier: "×1,5", logo: "/logos/11-la-fleche-wallonne.png" },
  { order: 12, name: "Liège–Bastogne–Liège", stars: 5, multiplier: "×2", logo: "/logos/12-liege-bastogne-liege.png" },
];

export default function CalendarioPage() {
  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Calendario 2027
      </div>
      <h1 className="text-2xl text-verde-deep">Las 12 clásicas</h1>
      <p className="mt-2 max-w-prose text-sm text-text-soft">
        De finales de febrero a finales de abril, con su categoría y el
        coeficiente que aporta a la puntuación.
      </p>

      <div className="mt-6 grid gap-3 sm:grid-cols-2">
        {RACES.map((race) => (
          <div
            key={race.order}
            className="flex items-center gap-4 rounded-2xl border border-line bg-surface p-3"
          >
            <div
              className={`h-16 w-16 shrink-0 overflow-hidden rounded-xl border-2 border-white ${
                race.darkTile ? "bg-[var(--hero-bg-1)]" : "bg-white"
              }`}
            >
              <Image
                src={race.logo}
                alt={race.name}
                width={64}
                height={64}
                className="h-full w-full object-cover"
              />
            </div>
            <div className="min-w-0 flex-1">
              <div className="font-display text-[11px] text-text-soft">
                {String(race.order).padStart(2, "0")}
              </div>
              <div className="truncate text-sm font-semibold">{race.name}</div>
              <div className="mt-0.5 text-amarillo" aria-label={`${race.stars} estrellas`}>
                {"★".repeat(race.stars)}
                <span className="text-line">{"★".repeat(5 - race.stars)}</span>
              </div>
            </div>
            <span className="shrink-0 rounded-full bg-rosa px-2.5 py-1 font-display text-[11px] font-semibold text-white">
              {race.multiplier}
            </span>
          </div>
        ))}
      </div>

      <div className="mt-6 flex flex-wrap gap-x-4 gap-y-2 text-[11px] text-text-soft">
        <span>★★ = ×1</span>
        <span>★★★ = ×1,5</span>
        <span>★★★★ = ×1,75</span>
        <span>★★★★★ = ×2 (Monumentos)</span>
      </div>

      <div className="mt-4 rounded-lg border-l-[3px] border-verde bg-surface p-3 text-[13px] leading-relaxed text-text-soft">
        Las cinco estrellas son los cuatro Monumentos de la porra:
        Milano–Sanremo, Ronde van Vlaanderen, Paris–Roubaix y
        Liège–Bastogne–Liège.
      </div>
    </div>
  );
}
EOF

git add -A
git commit -m "Logo grande en portada y logos de carreras a sangre en el calendario

- La portada usa ahora el logo UKT (mismo estilo pave del encabezado)
  en vez del texto plano
- Los logos de las 12 clasicas en /calendario llenan todo el recuadro
  (object-cover) con un borde blanco fino, en vez de quedar centrados
  con margen

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016LatMv4fA2uvbQTCSnJG6u"
git push
