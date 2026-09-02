import Link from "next/link";
import type { SessionPayload } from "@/lib/auth";
import LogoutButton from "@/components/logout-button";

export default function SiteHeader({
  session,
}: {
  session: SessionPayload | null;
}) {
  return (
    <header className="sticky top-0 z-20 border-b border-line bg-[var(--bg)]/92 backdrop-blur-sm">
      <div className="mx-auto flex max-w-4xl items-center justify-between gap-4 px-5 py-3">
        <Link href="/" className="font-display text-lg tracking-wide text-verde-deep">
          UKT
        </Link>
        <nav className="flex flex-wrap items-center gap-1 text-xs">
          <NavLink href="/reglamento">Reglamento</NavLink>
          <NavLink href="/calendario">Calendario</NavLink>
          {session?.status === "approved" && (
            <>
              <NavLink href="/mi-equipo">Mi equipo</NavLink>
              <NavLink href="/clasificacion">Clasificación</NavLink>
            </>
          )}
          {session?.role === "admin" && <NavLink href="/admin">Admin</NavLink>}
          {session ? (
            <LogoutButton />
          ) : (
            <>
              <NavLink href="/login">Entrar</NavLink>
              <Link
                href="/signup"
                className="ml-1 rounded-full bg-verde px-3 py-1.5 font-display text-[11px] uppercase tracking-wide text-[var(--hero-text)]"
              >
                Crear cuenta
              </Link>
            </>
          )}
        </nav>
      </div>
    </header>
  );
}

function NavLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="rounded-full px-3 py-1.5 font-display text-[11px] uppercase tracking-wide text-[var(--pill-text)] hover:bg-[var(--pill-bg)]"
    >
      {children}
    </Link>
  );
}
