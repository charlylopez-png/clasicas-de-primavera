"use client";

import { useEffect, useRef } from "react";
import { paintCobble, type PaintCobbleOptions } from "@/lib/ukt-cobble";

// Fondo con textura de adoquinado (elemento gráfico de la marca UKT).
// Se coloca dentro de un contenedor con position: relative; se pinta
// a pantalla completa detrás del contenido. Repinta al redimensionar.
export default function CobbleBackground({
  className,
  ...opts
}: PaintCobbleOptions & { className?: string }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    paintCobble(canvas, opts);
    const onResize = () => paintCobble(canvas, opts);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <canvas
      ref={ref}
      aria-hidden="true"
      className={className ?? "absolute inset-0 h-full w-full"}
    />
  );
}
