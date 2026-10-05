import { redirect } from "next/navigation";

// La portada de Il Lombardia es el propio menú de pestañas (ver layout.tsx);
// aquí solo redirigimos a la pantalla de partida.
export default function LombardiaPage() {
  redirect("/lombardia/eleccion");
}
