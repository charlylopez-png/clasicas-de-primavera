"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const ITEMS = [
  { href: "/lombardia/eleccion", label: "Elección de equipo" },
  { href: "/lombardia/equipo", label: "Mi equipo" },
  { href: "/lombardia/clasificacion", label: "Clasificación" },
  { href: "/lombardia/data", label: "Data" },
  { href: "/lombardia/perfil", label: "Perfil y mapa" },
];

const ADMIN_ITEMS = [
  { href: "/lombardia/corredores", label: "Corredores" },
  { href: "/lombardia/equipos", label: "Equipos" },
  { href: "/lombardia/resultados", label: "Resultados" },
];

export default function LombardiaSubNav({ isAdmin }: { isAdmin: boolean }) {
  const pathname = usePathname();
  const items = isAdmin ? [...ITEMS, ...ADMIN_ITEMS] : ITEMS;

  return (
    <nav className="flex flex-wrap gap-1.5">
      {items.map((item) => {
        const active = pathname === item.href;
        return (
          <Link
            key={item.href}
            href={item.href}
            className={`rounded-full px-3.5 py-2 font-display text-xs uppercase tracking-wide transition ${
              active
                ? "bg-verde-deep text-on-accent"
                : "border border-line bg-surface text-text-soft hover:border-verde-deep/50"
            }`}
          >
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
