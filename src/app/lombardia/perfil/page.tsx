const STATS = [
  { label: "Fecha", value: "Sábado 10 de octubre de 2026" },
  { label: "Recorrido", value: "Bérgamo → Como" },
  { label: "Distancia", value: "239 km" },
  { label: "Edición", value: "120ª — Monumento" },
];

// Puertos en orden de carrera. Longitud y pendiente media según Cyclingnews;
// la web oficial confirma el orden y los detalles de cada subida.
const CLIMBS = [
  { name: "Bocche del Gavarno", detail: "3,1 km al 4,7%" },
  { name: "Selvino", detail: "10,1 km al 5,9% — la subida de los tornanti desde la Val Seriana." },
  { name: "Colle di Berbenno", detail: "4,5 km al 6,3%" },
  { name: "Valpiana", detail: "10,1 km al 6,2%" },
  { name: "Giovenzana (Colle Brianza)", detail: "3,6 km al 9,2%" },
  { name: "Madonna del Ghisallo", detail: "8,6 km al 6,2% — la subida mítica del ciclismo, con rampas de hasta el 14%." },
  { name: "San Fermo della Battaglia (1ª vez)", detail: "2,7 km al 7,2%" },
  { name: "Civiglio", detail: "4,2 km al 9,7% — pendiente casi constante en torno al 10% y calzada más estrecha en la cima." },
  { name: "San Fermo della Battaglia (2ª vez)", detail: "2,7 km al 7,2% — última subida, a falta de unos 10 km de meta." },
];

export default function LombardiaPerfilPage() {
  return (
    <section>
      <h2 className="font-display text-sm text-verde-deep">Perfil y mapa de la carrera</h2>
      <p className="mt-1 max-w-prose text-sm text-text-soft">
        El Giro de Lombardía, «la clásica de las hojas muertas», cierra la
        temporada de los Monumentos. Sale de Bérgamo en dirección Val Seriana,
        encadena una serie de subidas en las Prealpes y termina en Como tras
        una doble ascensión a San Fermo della Battaglia: la segunda,
        con bajada final por dos túneles y meta en asfalto sobre una recta de
        7 m de ancho.
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

      <h3 className="mt-6 font-display text-sm text-verde-deep">Las subidas, en orden</h3>
      <ol className="mt-2 grid gap-2">
        {CLIMBS.map((c, i) => (
          <li
            key={c.name}
            className="flex gap-3 rounded-xl border border-line bg-surface p-3"
          >
            <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[var(--pill-bg)] font-display text-xs text-verde-deep">
              {i + 1}
            </span>
            <div className="min-w-0">
              <div className="font-display text-sm text-verde-deep">{c.name}</div>
              <div className="text-xs text-text-soft">{c.detail}</div>
            </div>
          </li>
        ))}
      </ol>

      <div className="mt-6 rounded-2xl border border-dashed border-line bg-surface p-4 text-center">
        <p className="text-sm text-text-soft">
          Altimetría, planimetría, crono-tabla y mapa oficial del recorrido en
          la web de la carrera:
        </p>
        <a
          href="https://www.ilombardia.it/percorso/"
          target="_blank"
          rel="noopener noreferrer"
          className="mt-2 inline-flex items-center gap-1 font-display text-xs uppercase tracking-wide text-verde-deep underline underline-offset-2"
        >
          Web oficial de Il Lombardia ↗
        </a>
      </div>

      <p className="mt-4 text-[11px] text-text-faint">
        Fuentes:{" "}
        <a
          href="https://www.ilombardia.it/percorso/"
          target="_blank"
          rel="noopener noreferrer"
          className="underline underline-offset-2"
        >
          ilombardia.it
        </a>{" "}
        ·{" "}
        <a
          href="https://www.cyclingnews.com/pro-cycling/racing/il-lombardia-2026-route-to-include-double-ascent-of-crunch-san-fermo-della-battaglia-climb/"
          target="_blank"
          rel="noopener noreferrer"
          className="underline underline-offset-2"
        >
          Cyclingnews
        </a>
      </p>
    </section>
  );
}
