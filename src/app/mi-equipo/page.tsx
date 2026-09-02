import { getSession } from "@/lib/auth";

export default async function MiEquipoPage() {
  const session = await getSession();

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Tu plantilla
      </div>
      <h1 className="text-2xl text-verde-deep">
        Hola, {session?.displayName ?? "participante"}
      </h1>
      <div className="mt-6 rounded-2xl border border-dashed border-line bg-surface p-8 text-center">
        <p className="text-sm text-text-soft">
          Próximamente: aquí elegirás tu Equipo Base (6 corredores fijos) y
          tu Last Draft para cada carrera.
        </p>
      </div>
    </div>
  );
}
