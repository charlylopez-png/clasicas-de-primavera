"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const ITEMS = [
  { href: "/mundial/eleccion", label: "Elección de equipo" },
  { href: "/mundial/equipo", label: "Mi equipo" },
  { href: "/mundial/clasificacion", label: "Clasificación" },
  { href: "/mundial/perfil", label: "Perfil y mapa" },
];

const ADMIN_ITEMS = [
  { href: "/mundial/corredores", label: "Corredores" },
  { href: "/mundial/resultados", label: "Resultados" },
];

export default function MundialSubNav({ isAdmin }: { isAdmin: boolean }) {
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
