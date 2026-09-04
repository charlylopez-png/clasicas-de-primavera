import Link from "next/link";
import Logo from "@/components/logo";
import CobbleBackground from "@/components/cobble-background";

export default function Home() {
  return (
    <>
      <section className="relative overflow-hidden px-5 py-14 text-[var(--hero-text)] sm:py-20">
        <CobbleBackground cell={0.13} seed={7} />
        <div
          className="pointer-events-none absolute inset-0"
          style={{
            background:
              "radial-gradient(120% 90% at 30% 20%, rgba(4,16,10,0.72), rgba(4,16,10,0.25) 55%, rgba(4,16,10,0.55))",
          }}
        />
        <div className="relative mx-auto max-w-3xl">
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
              className="rounded-full bg-amarillo px-5 py-2.5 font-display text-xs uppercase tracking-wide text-on-accent hover:bg-gold"
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
