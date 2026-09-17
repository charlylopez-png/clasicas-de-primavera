import { sql } from "@/lib/db";
import UserActions from "@/components/user-actions";
import SanedrinToggle from "@/components/sanedrin-toggle";
import ManualPlayerForm from "@/components/manual-player-form";
import DeleteManualPlayerButton from "@/components/delete-manual-player-button";
import ImpersonateButton from "@/components/impersonate-button";
import ResetPasswordButton from "@/components/reset-password-button";

type UserRow = {
  id: string;
  email: string;
  display_name: string;
  status: "pending" | "approved" | "rejected";
  role: "admin" | "participant";
  is_sanedrin: boolean;
  is_manual: boolean;
  created_at: string;
};

const SANEDRIN_LIMIT = 3;

export default async function AdminPage() {
  const users = (await sql`
    select id, email, display_name, status, role, is_sanedrin, is_manual, created_at
    from users
    order by (status = 'pending') desc, created_at desc
  `) as UserRow[];

  const pending = users.filter((u) => u.status === "pending");
  const resolved = users.filter((u) => u.status !== "pending");
  const sanedrinCount = users.filter((u) => u.is_sanedrin).length;

  return (
    <div className="mx-auto max-w-3xl px-5 py-10">
      <div className="mb-1 flex items-center gap-2 font-display text-[11px] uppercase tracking-[0.16em] text-verde">
        <span className="h-1.5 w-1.5 rounded-full bg-amarillo" />
        Administración
      </div>
      <h1 className="text-2xl text-verde-deep">Participantes</h1>
      <p className="mt-2 text-sm text-text-soft">
        Aprueba o rechaza a quien se apunte a la porra. Solo los aprobados
        pueden elegir equipo y ver la clasificación.
      </p>

      <section className="mt-8">
        <h2 className="font-display text-sm text-verde-deep">Jugadores manuales</h2>
        <p className="mt-1 text-xs text-text-soft">
          Para gente que no va a entrar por su cuenta en la app (mayores con
          dificultades con la tecnología, por ejemplo): añádelos con solo su
          nombre, sin cuenta ni contraseña, y usa &quot;Actuar como&quot; más
          abajo para fichar por ellos en las clásicas o en el Mundial, igual
          que haría cualquier jugador.
        </p>
        <div className="mt-3">
          <ManualPlayerForm />
        </div>
      </section>

      <section className="mt-8">
        <h2 className="font-display text-sm text-verde-deep">
          Pendientes ({pending.length})
        </h2>
        {pending.length === 0 ? (
          <p className="mt-2 text-sm text-text-soft">No hay nadie esperando.</p>
        ) : (
          <div className="mt-3 flex flex-col gap-2">
            {pending.map((u) => (
              <div
                key={u.id}
                className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-line bg-surface p-3"
              >
                <div className="min-w-0">
                  <div className="truncate text-base font-semibold">{u.display_name}</div>
                  <div className="truncate text-sm text-text-soft">{u.email}</div>
                </div>
                <UserActions userId={u.id} />
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="mt-8">
        <div className="flex items-center justify-between">
          <h2 className="font-display text-sm text-verde-deep">Resto</h2>
          <span className="rounded-full bg-surface px-2.5 py-1 text-[11px] text-text-soft">
            Sanedrín: {sanedrinCount}/{SANEDRIN_LIMIT}
          </span>
        </div>
        <p className="mt-1 text-xs text-text-soft">
          El Sanedrín tiene acceso previo a la base de datos de corredores
          para clasificarlos. Como mucho {SANEDRIN_LIMIT} a la vez.
        </p>
        <div className="mt-3 flex flex-col gap-2">
          {resolved.map((u) => (
            <div
              key={u.id}
              className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-line bg-surface p-3"
            >
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="truncate text-base font-semibold">{u.display_name}</span>
                  {u.is_manual && (
                    <span className="shrink-0 rounded-full border border-line px-2 py-0.5 text-[10px] uppercase tracking-wide text-text-soft">
                      Sin cuenta
                    </span>
                  )}
                </div>
                <div className="truncate text-sm text-text-soft">
                  {u.is_manual ? "Gestionado por ti" : u.email}
                </div>
              </div>
              <div className="flex w-full flex-wrap items-center justify-end gap-2 sm:w-auto sm:shrink-0">
                <span
                  className={`shrink-0 rounded-full px-2.5 py-1 text-[11px] font-semibold ${
                    u.status === "approved"
                      ? "bg-verde text-on-accent"
                      : "bg-rosa text-on-accent"
                  }`}
                >
                  {u.status === "approved" ? "Aprobado" : "Rechazado"}
                  {u.role === "admin" ? " · Admin" : ""}
                </span>
                {u.status === "approved" && u.role !== "admin" && (
                  <>
                    <SanedrinToggle
                      userId={u.id}
                      isSanedrin={u.is_sanedrin}
                      disabled={sanedrinCount >= SANEDRIN_LIMIT}
                    />
                    <ImpersonateButton userId={u.id} />
                    {!u.is_manual && (
                      <ResetPasswordButton userId={u.id} displayName={u.display_name} />
                    )}
                  </>
                )}
                {u.is_manual && <DeleteManualPlayerButton userId={u.id} />}
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
