#!/usr/bin/env bash
set -e

mkdir -p src/components src/app/calendario src/app/reglamento db

cat > src/components/logo.tsx << 'EOF'
// Wordmark "UKT" al estilo de los carteles de sectores de pavé de las
// clásicas (Paris–Roubaix, Ronde van Vlaanderen…): letras sólidas
// "fracturadas" en piezas, como si estuvieran hechas de adoquines.
// El color usa el token --pill-text, que ya se adapta solo entre modo
// claro y oscuro.
export default function Logo({ className }: { className?: string }) {
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
        fill="var(--pill-text)"
        mask="url(#ukt-cuts)"
      >
        UKT
      </text>
    </svg>
  );
}
EOF

cat > src/components/mobile-nav.tsx << 'EOF'
"use client";

import Link from "next/link";
import { useState } from "react";

type NavItem = { href: string; label: string };

export default function MobileNav({
  items,
  children,
}: {
  items: NavItem[];
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(false);

  return (
    <div className="sm:hidden">
      <button
        type="button"
        aria-label={open ? "Cerrar menú" : "Abrir menú"}
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
        className="flex h-10 w-10 items-center justify-center rounded-full border border-line text-text"
      >
        {open ? (
          <svg
            width="18"
            height="18"
            viewBox="0 0 18 18"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
          >
            <path d="M2 2l14 14M16 2L2 16" />
          </svg>
        ) : (
          <svg
            width="20"
            height="14"
            viewBox="0 0 20 14"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
          >
            <path d="M1 1h18M1 7h18M1 13h18" />
          </svg>
        )}
      </button>

      {open && (
        <div className="absolute inset-x-0 top-full z-30 border-b border-line bg-[var(--bg)] px-5 pb-4 pt-1 shadow-lg">
          <nav
            className="flex flex-col divide-y divide-line"
            onClick={() => setOpen(false)}
          >
            {items.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="py-3.5 font-display text-base uppercase tracking-wide text-text"
              >
                {item.label}
              </Link>
            ))}
          </nav>
          <div
            className="mt-3 flex flex-col items-stretch gap-2 border-t border-line pt-3"
            onClick={() => setOpen(false)}
          >
            {children}
          </div>
        </div>
      )}
    </div>
  );
}
EOF

cat > src/components/site-header.tsx << 'EOF'
import Link from "next/link";
import type { SessionPayload } from "@/lib/auth";
import LogoutButton from "@/components/logout-button";
import MobileNav from "@/components/mobile-nav";
import Logo from "@/components/logo";

type NavItem = { href: string; label: string };

export default function SiteHeader({
  session,
}: {
  session: SessionPayload | null;
}) {
  const navItems: NavItem[] = [
    { href: "/reglamento", label: "Reglamento" },
    { href: "/calendario", label: "Calendario" },
  ];
  if (session?.status === "approved") {
    navItems.push(
      { href: "/mi-equipo", label: "Mi equipo" },
      { href: "/clasificacion", label: "Clasificación" }
    );
  }
  if (session?.role === "admin") {
    navItems.push({ href: "/admin", label: "Admin" });
  }

  return (
    <header className="sticky top-0 z-20 relative border-b border-line bg-[var(--bg)]/92 backdrop-blur-sm">
      <div className="mx-auto flex max-w-4xl items-center justify-between gap-4 px-5 py-2.5">
        <Link href="/" aria-label="UKT — Inicio" className="shrink-0">
          <Logo className="h-8 w-auto sm:h-9" />
        </Link>

        <nav className="hidden items-center gap-1 sm:flex">
          {navItems.map((item) => (
            <NavLink key={item.href} href={item.href}>
              {item.label}
            </NavLink>
          ))}
          <AuthActions session={session} />
        </nav>

        <MobileNav items={navItems}>
          <AuthActions session={session} />
        </MobileNav>
      </div>
    </header>
  );
}

function AuthActions({ session }: { session: SessionPayload | null }) {
  if (session) {
    return <LogoutButton />;
  }
  return (
    <div className="flex items-center gap-2 sm:gap-2">
      <NavLink href="/login">Entrar</NavLink>
      <Link
        href="/signup"
        className="rounded-full bg-verde px-4 py-2.5 text-center font-display text-xs uppercase tracking-wide text-[var(--hero-text)] sm:ml-1 sm:px-3.5 sm:py-2"
      >
        Crear cuenta
      </Link>
    </div>
  );
}

function NavLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="rounded-full px-3.5 py-2 font-display text-xs uppercase tracking-wide text-[var(--pill-text)] hover:bg-[var(--pill-bg)]"
    >
      {children}
    </Link>
  );
}
EOF

cat > src/components/logout-button.tsx << 'EOF'
"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";

export default function LogoutButton() {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  return (
    <button
      type="button"
      disabled={isPending}
      onClick={() => {
        startTransition(async () => {
          await fetch("/api/auth/logout", { method: "POST" });
          router.push("/");
          router.refresh();
        });
      }}
      className="rounded-full px-3.5 py-2 text-left font-display text-xs uppercase tracking-wide text-[var(--pill-text)] hover:bg-[var(--pill-bg)] disabled:opacity-50"
    >
      Salir
    </button>
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
              className={`flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-xl ${
                race.darkTile ? "bg-[var(--hero-bg-1)]" : "bg-white"
              }`}
            >
              <Image
                src={race.logo}
                alt={race.name}
                width={56}
                height={56}
                className="h-12 w-12 object-contain"
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

cat > src/app/reglamento/page.tsx << 'EOF'
export default function ReglamentoPage() {
  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <Kicker>Las reglas, en corto</Kicker>
      <h1 className="text-2xl text-verde-deep">Cómo funciona la porra</h1>
      <p className="mt-2 max-w-prose text-sm text-text-soft">
        Tres mecanismos evitan que la liga la gane siempre &quot;el más
        obvio&quot; y mantienen la pelea viva hasta la última carrera.
      </p>

      <div className="mt-8 grid gap-4 sm:grid-cols-3">
        <RuleCard n="01" title="Coeficientes" accent="verde">
          Carreras y corredores puntúan distinto según su categoría. Un
          favorito ganando una carrera menor vale bastante menos que una
          sorpresa triunfando en un Monumento.
        </RuleCard>
        <RuleCard n="02" title="Tu equipo" accent="amarillo">
          Plantilla de 12 corredores en dos bloques: el Equipo Base, fijo
          toda la temporada, y el Last Draft, que recompones carrera a
          carrera.
        </RuleCard>
        <RuleCard n="03" title="El Sprint" accent="rosa">
          Un duelo contra otro participante en cada carrera, sorteado al
          inicio de temporada. Ganarlo suma puntos extra; perderlo, los
          resta.
        </RuleCard>
      </div>

      <div
        className="mt-8 rounded-2xl p-6 text-[var(--hero-text)]"
        style={{ background: "var(--hero-bg-1)" }}
      >
        <h2 className="font-display text-xs tracking-wide text-amarillo">
          Fórmula de puntuación de cada corredor
        </h2>
        <div className="mt-3 rounded-xl border border-dashed border-white/35 bg-white/5 p-4 text-center font-display text-base">
          Puntos por puesto <span className="text-amarillo">×</span>{" "}
          Coeficiente de la carrera <span className="text-amarillo">×</span>{" "}
          Coeficiente del corredor
        </div>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          <Example title="Favorito claro">
            Amarillo (×1) gana la Milano–Sanremo (5★, ×2): 100 × 2 × 1 ={" "}
            <b className="text-amarillo">200 pts</b>
          </Example>
          <Example title="Sorpresa premiada">
            Verde (×2) es 5º en la Ronde van Vlaanderen (5★, ×2): 16 × 2 × 2 ={" "}
            <b className="text-amarillo">64 pts</b>
          </Example>
        </div>
      </div>

      <div className="mt-10">
        <Kicker>Puntuación base</Kicker>
        <h2 className="text-xl text-verde-deep">Puntos por puesto</h2>
        <p className="mt-2 max-w-prose text-sm text-text-soft">
          Puntuación de partida antes de aplicar los coeficientes.
          Puntúan los 20 primeros.
        </p>
        <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
          {POINTS.map(([pos, pts], i) => (
            <div
              key={pos}
              className={`flex items-center justify-between rounded-lg px-3 py-2 text-sm ${
                i < 3 ? "bg-amarillo text-[#2b2103] font-bold" : "bg-surface"
              }`}
            >
              <span>{pos}º</span>
              <b className="font-display">{pts}</b>
            </div>
          ))}
        </div>
      </div>

      <div className="mt-10">
        <Kicker>Tu plantilla</Kicker>
        <h2 className="text-xl text-verde-deep">Los corredores</h2>
        <p className="mt-2 max-w-prose text-sm text-text-soft">
          Cuanto menos favorito, más multiplica: una sorpresa bien elegida
          puede valer tanto como un ganador cantado.
        </p>
        <div className="mt-4 grid gap-4 sm:grid-cols-3">
          <CategoryCard
            name="Amarillo"
            mult="×1"
            className="bg-gradient-to-br from-[#f0c23a] to-[#c68a06] text-[#372802]"
          >
            Top élite y favoritos indiscutibles (Pogačar, MVDP…). Ganan a
            menudo, pero apenas multiplican.
          </CategoryCard>
          <CategoryCard
            name="Rosa"
            mult="×1,5"
            className="bg-gradient-to-br from-[#ef6ea0] to-[#c53f74] text-white"
          >
            Corredores de élite, candidatos serios sin ser los favoritos
            absolutos.
          </CategoryCard>
          <CategoryCard
            name="Verde"
            mult="×2"
            className="bg-gradient-to-br from-[#4fa576] to-[#215f3e] text-white"
          >
            El resto del pelotón. Menos probable que puntúen, pero cuando lo
            hacen, multiplican por dos.
          </CategoryCard>
        </div>

        <div className="mt-4 rounded-2xl bg-surface p-5">
          <SquadBlock title="Equipo Base" when="Fijo para toda la temporada" />
          <div className="my-3 border-t border-dashed border-line" />
          <SquadBlock title="Last Draft" when="Se recompone antes de cada carrera" />
          <div className="mt-3 border-t border-dashed border-line pt-3 text-center font-display text-xs tracking-wide text-verde-deep">
            6 + 6 = 12 CORREDORES EN TU PLANTILLA
          </div>
        </div>
      </div>

      <div className="mt-10 pb-6">
        <Kicker>La guinda</Kicker>
        <h2 className="text-xl text-verde-deep">El Sprint</h2>
        <div
          className="mt-4 rounded-2xl p-5 text-sm leading-relaxed text-white"
          style={{ background: "linear-gradient(135deg, var(--accent-rosa, #c53f74), #a63464)" }}
        >
          &quot;La máquina&quot; sortea al inicio de temporada un rival
          distinto para cada una de las 12 carreras. En cada una, además de
          tus puntos, se compara tu puntuación de esa jornada con la de tu
          rival de turno.
        </div>
        <div className="mt-4 flex items-center gap-3">
          <div className="flex-1 rounded-xl border-2 border-verde bg-surface py-5 text-center">
            <div className="font-display text-3xl font-bold text-verde">+100</div>
            <div className="mt-1 text-[10px] uppercase tracking-wide text-text-soft">
              Gana el Sprint
            </div>
          </div>
          <div className="font-display text-sm text-text-soft">VS</div>
          <div className="flex-1 rounded-xl border-2 border-rosa bg-surface py-5 text-center">
            <div className="font-display text-3xl font-bold text-rosa">−50</div>
            <div className="mt-1 text-[10px] uppercase tracking-wide text-text-soft">
              Pierde el Sprint
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

const POINTS: [number, number][] = [
  [1, 100], [2, 50], [3, 30], [4, 20], [5, 16], [6, 15], [7, 14], [8, 13],
  [9, 12], [10, 11], [11, 10], [12, 9], [13, 8], [14, 7], [15, 6], [16, 5],
  [17, 4], [18, 3], [19, 2], [20, 1],
];

function Kicker({ children }: { children: React.ReactNode }) {
  return (
    <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
      <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
      {children}
    </div>
  );
}

function RuleCard({
  n,
  title,
  accent,
  children,
}: {
  n: string;
  title: string;
  accent: "verde" | "amarillo" | "rosa";
  children: React.ReactNode;
}) {
  const borderColor =
    accent === "verde"
      ? "border-t-verde"
      : accent === "amarillo"
      ? "border-t-amarillo"
      : "border-t-rosa";
  return (
    <div className={`rounded-2xl border-t-4 bg-surface p-4 ${borderColor}`}>
      <div className="font-display text-[11px] text-text-soft">{n}</div>
      <h3 className="mt-1 text-base text-verde-deep">{title}</h3>
      <p className="mt-1.5 text-[13px] leading-relaxed text-text-soft">
        {children}
      </p>
    </div>
  );
}

function Example({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-xl bg-white/5 p-3 text-[13px] leading-relaxed">
      <b className="text-amarillo">{title}.</b> {children}
    </div>
  );
}

function CategoryCard({
  name,
  mult,
  className,
  children,
}: {
  name: string;
  mult: string;
  className: string;
  children: React.ReactNode;
}) {
  return (
    <div className={`rounded-2xl p-4 ${className}`}>
      <div className="flex items-baseline justify-between">
        <span className="font-display text-base font-bold">{name}</span>
        <span className="font-display text-xl font-bold">{mult}</span>
      </div>
      <p className="mt-1.5 text-[13px] leading-relaxed">{children}</p>
    </div>
  );
}

function SquadBlock({ title, when }: { title: string; when: string }) {
  return (
    <div>
      <h4 className="font-display text-sm text-verde-deep">{title}</h4>
      <div className="mb-2 text-[11px] text-text-soft">{when}</div>
      <div className="flex flex-wrap gap-2">
        <Tag>Amarillo ×1</Tag>
        <Tag>Rosa ×2</Tag>
        <Tag>Verde ×3</Tag>
      </div>
    </div>
  );
}

function Tag({ children }: { children: React.ReactNode }) {
  return (
    <span className="rounded-lg border border-line bg-bg px-2.5 py-1 text-[12px]">
      {children}
    </span>
  );
}
EOF

sed -i 's/multiplicador y logo/coeficiente y logo/' db/schema.sql

git add -A
git commit -m "Rediseña encabezado (menú móvil + logo pavé) y cambia multiplicador por coeficiente

- Nuevo logo UKT: letras solidas fracturadas en piezas al estilo de los
  carteles de sectores de pave (Paris-Roubaix)
- Encabezado movil: menu hamburguesa con filas grandes y tocables en vez
  de pildoras diminutas envueltas en dos lineas
- Sustituye multiplicador/multiplicadores por coeficiente/coeficientes
  en reglamento, calendario y el esquema de base de datos

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_016LatMv4fA2uvbQTCSnJG6u"
git push
