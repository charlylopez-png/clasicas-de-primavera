import { redirect } from "next/navigation";

// La portada del Mundial es el propio menú de pestañas (ver layout.tsx);
// aquí solo redirigimos a la pantalla de partida.
export default function MundialPage() {
  redirect("/mundial/eleccion");
}
