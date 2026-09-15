const STATS = [
  { label: "Fecha", value: "Domingo 27 de septiembre de 2026" },
  { label: "Distancia total", value: "273,4 km" },
  { label: "Desnivel total", value: "3.803 m" },
  { label: "Circuito final", value: "13,4 km, en el Mont Royal" },
  { label: "Vueltas al circuito", value: "≈ 12" },
  { label: "Desnivel por vuelta", value: "≈ 269 m" },
];

const CLIMBS = [
  {
    name: "Voie Camillien-Houde",
    detail: "2,3 km al 6,2% de media — la ascensión principal del circuito, varias veces por vuelta.",
  },
  {
    name: "Côte de la Polytechnique",
    detail: "Corta pero muy dura, con rampas por encima del 11% en su tramo central.",
  },
  {
    name: "Avenue du Parc (meta)",
    detail: "Falso llano en ascenso hasta la línea de meta — decide la carrera al sprint o en solitario según cómo llegue el grupo.",
  },
];

export default function MundialPerfilPage() {
  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Perfil y mapa de la carrera</h2>
      <p className="mt-1 max-w-prose text-sm text-text-soft">
        La prueba en línea élite masculina sale de Brossard (región de la
        Montérégie), cruza el puente Samuel De Champlain hacia Montreal y
        termina con varias vueltas a un circuito exigente alrededor del
        Mont Royal.
      </p>

      <div className="mt-4 grid grid-cols-2 gap-2.5 sm:grid-cols-3">
        {STATS.map((s) => (
          <div key={s.label} className="rounded-xl border border-line bg-surface p-3">
            <div className="text-[11px] uppercase tracking-wide text-text-soft">
              {s.label}
            </div>
            <div className="mt-0.5 font-display text-sm text-verde-deep">{s.value}</div>
          </div>
        ))}
      </div>

      <h3 className="mt-6 font-display text-xs uppercase tracking-wide text-verde-deep">
        Puntos clave del circuito
      </h3>
      <div className="mt-2 flex flex-col gap-2">
        {CLIMBS.map((c) => (
          <div key={c.name} className="rounded-xl border border-line bg-surface p-3.5">
            <div className="font-display text-sm text-amarillo">{c.name}</div>
            <p className="mt-1 text-[13px] leading-relaxed text-text-soft">{c.detail}</p>
          </div>
        ))}
      </div>

      <div className="mt-6 rounded-2xl border border-dashed border-line bg-surface p-4 text-center">
        <p className="text-sm text-text-soft">
          Para el mapa interactivo y el perfil de altimetría oficiales, consulta
          la web del evento:
        </p>
        <a
          href="https://www.montreal2026.org/en/challenge/mens-elite/"
          target="_blank"
          rel="noopener noreferrer"
          className="mt-2 inline-flex items-center gap-1 font-display text-xs uppercase tracking-wide text-verde-deep underline underline-offset-2"
        >
          Web oficial — Men&apos;s Elite Road Race ↗
        </a>
      </div>

      <p className="mt-4 text-[11px] text-text-faint">
        Fuentes:{" "}
        <a
          href="https://en.wikipedia.org/wiki/2026_UCI_Road_World_Championships"
          target="_blank"
          rel="noopener noreferrer"
          className="underline underline-offset-2"
        >
          Wikipedia
        </a>{" "}
        ·{" "}
        <a
          href="https://procyclinguk.com/gp-montreal-2026-route-guide-world-championships-circuit-packs-in-4304-metres-of-climbing/"
          target="_blank"
          rel="noopener noreferrer"
          className="underline underline-offset-2"
        >
          ProCyclingUK
        </a>
      </p>
    </section>
  );
}
