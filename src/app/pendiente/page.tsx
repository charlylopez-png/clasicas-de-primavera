import { getSession } from "@/lib/auth";

export default async function PendientePage() {
  const session = await getSession();

  if (session?.status === "rejected") {
    return (
      <div className="mx-auto max-w-md px-5 py-20 text-center">
        <h1 className="text-2xl text-verde-deep">Solicitud no aceptada</h1>
        <p className="mt-3 text-sm text-text-soft">
          El organizador no ha aprobado tu cuenta para esta temporada. Si
          crees que es un error, contacta directamente con él.
        </p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-md px-5 py-20 text-center">
      <h1 className="text-2xl text-verde-deep">Cuenta pendiente de aprobación</h1>
      <p className="mt-3 text-sm text-text-soft">
        Ya tienes cuenta,
        {session?.displayName ? ` ${session.displayName}` : ""}. En cuanto el
        organizador la apruebe podrás elegir tu equipo y ver la
        clasificación. Mientras tanto puedes consultar el reglamento y el
        calendario.
      </p>
    </div>
  );
}
