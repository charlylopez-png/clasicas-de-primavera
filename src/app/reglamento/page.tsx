export default function ReglamentoPage() {
  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <Kicker>Las reglas, en corto</Kicker>
      <h1 className="text-2xl text-verde-deep">Cómo funciona la porra</h1>
      <p className="mt-2 max-w-prose text-sm text-text-soft">
        Tres mecanismos evitan que la liga la gane siempre &quot;el más
        obvio&quot; y mantienen la pelea viva hasta la última carrera.
      </p>

      <div className="mt-8 grid gap-4 sm:grid-cols-3">
        <RuleCard n="01" title="Coeficientes" accent="verde">
          Carreras y corredores puntúan distinto según su categoría. Un
          favorito ganando una carrera menor vale bastante menos que una
          sorpresa triunfando en un Monumento.
        </RuleCard>
        <RuleCard n="02" title="Tu equipo" accent="amarillo">
          Plantilla de 12 corredores en dos bloques: el Equipo Base, fijo
          toda la temporada, y el Last Draft, que recompones carrera a
          carrera.
        </RuleCard>
        <RuleCard n="03" title="El Sprint" accent="rosa">
          Un duelo contra otro participante en cada carrera, sorteado al
          inicio de temporada. Ganarlo suma puntos extra; perderlo, los
          resta.
        </RuleCard>
      </div>

      <div
        className="mt-8 rounded-2xl p-6 text-[var(--hero-text)]"
        style={{ background: "var(--hero-bg-1)" }}
      >
        <h2 className="font-display text-xs tracking-wide text-amarillo">
          Fórmula de puntuación de cada corredor
        </h2>
        <div className="mt-3 rounded-xl border border-dashed border-white/35 bg-white/5 p-4 text-center font-display text-base">
          Puntos por puesto <span className="text-amarillo">×</span>{" "}
          Coeficiente de la carrera <span className="text-amarillo">×</span>{" "}
          Coeficiente del corredor
        </div>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          <Example title="Favorito claro">
            Amarillo (×1) gana la Milano–Sanremo (5★, ×2): 100 × 2 × 1 ={" "}
            <b className="text-amarillo">200 pts</b>
          </Example>
          <Example title="Sorpresa premiada">
            Verde (×2) es 5º en la Ronde van Vlaanderen (5★, ×2): 16 × 2 × 2 ={" "}
            <b className="text-amarillo">64 pts</b>
          </Example>
        </div>
      </div>

      <div className="mt-10">
        <Kicker>Puntuación base</Kicker>
        <h2 className="text-xl text-verde-deep">Puntos por puesto</h2>
        <p className="mt-2 max-w-prose text-sm text-text-soft">
          Puntuación de partida antes de aplicar los coeficientes.
          Puntúan los 20 primeros.
        </p>
        <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
          {POINTS.map(([pos, pts], i) => (
            <div
              key={pos}
              className={`flex items-center justify-between rounded-lg px-3 py-2 text-sm ${
                i < 3 ? "bg-amarillo text-[#2b2103] font-bold" : "bg-surface"
              }`}
            >
              <span>{pos}º</span>
              <b className="font-display">{pts}</b>
            </div>
          ))}
        </div>
      </div>

      <div className="mt-10">
        <Kicker>Tu plantilla</Kicker>
        <h2 className="text-xl text-verde-deep">Los corredores</h2>
        <p className="mt-2 max-w-prose text-sm text-text-soft">
          Cuanto menos favorito, más multiplica: una sorpresa bien elegida
          puede valer tanto como un ganador cantado.
        </p>
        <div className="mt-4 grid gap-4 sm:grid-cols-3">
          <CategoryCard
            name="Amarillo"
            mult="×1"
            className="bg-gradient-to-br from-[#f0c23a] to-[#c68a06] text-[#372802]"
          >
            Top élite y favoritos indiscutibles (Pogačar, MVDP…). Ganan a
            menudo, pero apenas multiplican.
          </CategoryCard>
          <CategoryCard
            name="Rosa"
            mult="×1,5"
            className="bg-gradient-to-br from-[#ef6ea0] to-[#c53f74] text-white"
          >
            Corredores de élite, candidatos serios sin ser los favoritos
            absolutos.
          </CategoryCard>
          <CategoryCard
            name="Verde"
            mult="×2"
            className="bg-gradient-to-br from-[#4fa576] to-[#215f3e] text-white"
          >
            El resto del pelotón. Menos probable que puntúen, pero cuando lo
            hacen, multiplican por dos.
          </CategoryCard>
        </div>

        <div className="mt-4 rounded-2xl bg-surface p-5">
          <SquadBlock title="Equipo Base" when="Fijo para toda la temporada" />
          <div className="my-3 border-t border-dashed border-line" />
          <SquadBlock title="Last Draft" when="Se recompone antes de cada carrera" />
          <div className="mt-3 border-t border-dashed border-line pt-3 text-center font-display text-xs tracking-wide text-verde-deep">
            6 + 6 = 12 CORREDORES EN TU PLANTILLA
          </div>
        </div>
      </div>

      <div className="mt-10 pb-6">
        <Kicker>La guinda</Kicker>
        <h2 className="text-xl text-verde-deep">El Sprint</h2>
        <div
          className="mt-4 rounded-2xl p-5 text-sm leading-relaxed text-white"
          style={{ background: "linear-gradient(135deg, var(--accent-rosa, #c53f74), #a63464)" }}
        >
          &quot;La máquina&quot; sortea al inicio de temporada un rival
          distinto para cada una de las 12 carreras. En cada una, además de
          tus puntos, se compara tu puntuación de esa jornada con la de tu
          rival de turno.
        </div>
        <div className="mt-4 flex items-center gap-3">
          <div className="flex-1 rounded-xl border-2 border-verde bg-surface py-5 text-center">
            <div className="font-display text-3xl font-bold text-verde">+100</div>
            <div className="mt-1 text-[10px] uppercase tracking-wide text-text-soft">
              Gana el Sprint
            </div>
          </div>
          <div className="font-display text-sm text-text-soft">VS</div>
          <div className="flex-1 rounded-xl border-2 border-rosa bg-surface py-5 text-center">
            <div className="font-display text-3xl font-bold text-rosa">−50</div>
            <div className="mt-1 text-[10px] uppercase tracking-wide text-text-soft">
              Pierde el Sprint
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

const POINTS: [number, number][] = [
  [1, 100], [2, 50], [3, 30], [4, 20], [5, 16], [6, 15], [7, 14], [8, 13],
  [9, 12], [10, 11], [11, 10], [12, 9], [13, 8], [14, 7], [15, 6], [16, 5],
  [17, 4], [18, 3], [19, 2], [20, 1],
];

function Kicker({ children }: { children: React.ReactNode }) {
  return (
    <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
      <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
      {children}
    </div>
  );
}

function RuleCard({
  n,
  title,
  accent,
  children,
}: {
  n: string;
  title: string;
  accent: "verde" | "amarillo" | "rosa";
  children: React.ReactNode;
}) {
  const borderColor =
    accent === "verde"
      ? "border-t-verde"
      : accent === "amarillo"
      ? "border-t-amarillo"
      : "border-t-rosa";
  return (
    <div className={`rounded-2xl border-t-4 bg-surface p-4 ${borderColor}`}>
      <div className="font-display text-[11px] text-text-soft">{n}</div>
      <h3 className="mt-1 text-base text-verde-deep">{title}</h3>
      <p className="mt-1.5 text-[13px] leading-relaxed text-text-soft">
        {children}
      </p>
    </div>
  );
}

function Example({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-xl bg-white/5 p-3 text-[13px] leading-relaxed">
      <b className="text-amarillo">{title}.</b> {children}
    </div>
  );
}

function CategoryCard({
  name,
  mult,
  className,
  children,
}: {
  name: string;
  mult: string;
  className: string;
  children: React.ReactNode;
}) {
  return (
    <div className={`rounded-2xl p-4 ${className}`}>
      <div className="flex items-baseline justify-between">
        <span className="font-display text-base font-bold">{name}</span>
        <span className="font-display text-xl font-bold">{mult}</span>
      </div>
      <p className="mt-1.5 text-[13px] leading-relaxed">{children}</p>
    </div>
  );
}

function SquadBlock({ title, when }: { title: string; when: string }) {
  return (
    <div>
      <h4 className="font-display text-sm text-verde-deep">{title}</h4>
      <div className="mb-2 text-[11px] text-text-soft">{when}</div>
      <div className="flex flex-wrap gap-2">
        <Tag>Amarillo ×1</Tag>
        <Tag>Rosa ×1,5</Tag>
        <Tag>Verde ×2</Tag>
      </div>
    </div>
  );
}

function Tag({ children }: { children: React.ReactNode }) {
  return (
    <span className="rounded-lg border border-line bg-bg px-2.5 py-1 text-[12px]">
      {children}
    </span>
  );
}
