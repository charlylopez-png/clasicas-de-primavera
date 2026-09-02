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
        multiplicador que aporta a la puntuación.
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
