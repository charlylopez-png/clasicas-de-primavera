const STATS = [
  { label: "Fecha", value: "Domingo 4 de octubre de 2026" },
  { label: "Sede", value: "Liubliana (Eslovenia)" },
  { label: "Distancia estimada", value: "≈ 196 km" },
  { label: "Categoría", value: "Élite masculina — Europeo UEC" },
];

export default function EuropeoPerfilPage() {
  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Perfil y mapa de la carrera</h2>
      <p className="mt-1 max-w-prose text-sm text-text-soft">
        El Europeo de carretera 2026 se disputa en Liubliana (Eslovenia) entre
        el 3 y el 7 de octubre, con la prueba en línea élite masculina el
        domingo 4. Va a ser una cita muy señalada: Slovenia organiza en casa
        con Pogačar y Roglič como máximos favoritos locales.
      </p>

      <div className="mt-4 grid grid-cols-2 gap-2.5 sm:grid-cols-4">
        {STATS.map((s) => (
          <div key={s.label} className="rounded-xl border border-line bg-surface p-3">
            <div className="text-[11px] uppercase tracking-wide text-text-soft">
              {s.label}
            </div>
            <div className="mt-0.5 font-display text-sm text-verde-deep">{s.value}</div>
          </div>
        ))}
      </div>

      <div className="mt-6 rounded-2xl border border-dashed border-line bg-surface p-4 text-center">
        <p className="text-sm text-text-soft">
          El circuito y el perfil de altimetría detallados todavía no están
          publicados oficialmente por la UEC a fecha de escribir esto — en
          cuanto se confirmen se pueden añadir aquí. Mientras tanto, la
          información más fiable está en la web oficial y en Wikipedia:
        </p>
        <a
          href="https://uec.ch/en/actu/348/ljubljana-to-host-2026-uec-road-european-championships"
          target="_blank"
          rel="noopener noreferrer"
          className="mt-2 inline-flex items-center gap-1 font-display text-xs uppercase tracking-wide text-verde-deep underline underline-offset-2"
        >
          Web oficial de la UEC ↗
        </a>
      </div>

      <p className="mt-4 text-[11px] text-text-faint">
        Fuentes:{" "}
        <a
          href="https://en.wikipedia.org/wiki/2026_European_Road_Championships"
          target="_blank"
          rel="noopener noreferrer"
          className="underline underline-offset-2"
        >
          Wikipedia
        </a>{" "}
        ·{" "}
        <a
          href="https://cyclingflash.com/race/uec-road-european-championships-2026/startlist"
          target="_blank"
          rel="noopener noreferrer"
          className="underline underline-offset-2"
        >
          CyclingFlash (startlist)
        </a>
      </p>
    </section>
  );
}
