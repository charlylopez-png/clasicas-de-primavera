import Image from "next/image";
import Link from "next/link";

// Ventana de visibilidad del banner: aparece hoy y se retira solo al
// empezar noviembre, cuando el Europeo ya haya pasado (carrera el 4 de
// octubre de 2026). Para cambiar las fechas basta con editar estas dos
// constantes.
const BANNER_START = new Date("2026-09-01T00:00:00");
const BANNER_END = new Date("2026-11-01T00:00:00");

export default function EuropeoHomeBanner() {
  const now = new Date();
  if (now < BANNER_START || now >= BANNER_END) return null;

  return (
    <Link
      href="/europeo"
      className="group relative mb-6 block overflow-hidden rounded-2xl border border-line bg-surface transition hover:border-verde-deep/50"
    >
      <div className="europeo-stripe" />
      <div className="flex items-center gap-4 p-4 sm:p-5">
        <div className="h-14 w-14 shrink-0 overflow-hidden rounded-xl border-2 border-white bg-white sm:h-16 sm:w-16">
          <Image
            src="/europeo-logos/ljubljana-2026.png"
            alt="Europeo de Ljubljana 2026"
            width={64}
            height={64}
            className="h-full w-full object-cover"
          />
        </div>
        <div className="min-w-0 flex-1">
          <div className="font-display text-[11px] uppercase tracking-[0.16em] text-amarillo">
            Prueba especial
          </div>
          <div className="font-display text-base text-verde-deep sm:text-lg">
            Europeo de Ljubljana 2026
          </div>
          <p className="mt-0.5 text-xs text-text-soft sm:text-sm">
            Elige tus 6 corredores antes del cierre →
          </p>
        </div>
        <span className="hidden shrink-0 rounded-full bg-amarillo px-4 py-2 font-display text-xs uppercase tracking-wide text-on-accent group-hover:bg-gold sm:inline-block">
          Entrar
        </span>
      </div>
    </Link>
  );
}
