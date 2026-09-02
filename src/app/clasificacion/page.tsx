export default function ClasificacionPage() {
  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        En vivo
      </div>
      <h1 className="text-2xl text-verde-deep">Clasificación</h1>
      <div className="mt-6 rounded-2xl border border-dashed border-line bg-surface p-8 text-center">
        <p className="text-sm text-text-soft">
          Próximamente: la clasificación general se calculará automáticamente
          en cuanto el organizador cargue los resultados de cada carrera.
        </p>
      </div>
    </div>
  );
}
