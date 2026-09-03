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
