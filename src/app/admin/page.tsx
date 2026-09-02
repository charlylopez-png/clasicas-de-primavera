import { sql } from "@/lib/db";
import UserActions from "@/components/user-actions";

type UserRow = {
  id: string;
  email: string;
  display_name: string;
  status: "pending" | "approved" | "rejected";
  role: "admin" | "participant";
  created_at: string;
};

export default async function AdminPage() {
  const users = (await sql`
    select id, email, display_name, status, role, created_at
    from users
    order by (status = 'pending') desc, created_at desc
  `) as UserRow[];

  const pending = users.filter((u) => u.status === "pending");
  const resolved = users.filter((u) => u.status !== "pending");

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
                className="flex items-center justify-between gap-3 rounded-xl border border-line bg-surface p-3"
              >
                <div className="min-w-0">
                  <div className="truncate text-sm font-semibold">{u.display_name}</div>
                  <div className="truncate text-xs text-text-soft">{u.email}</div>
                </div>
                <UserActions userId={u.id} />
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="mt-8">
        <h2 className="font-display text-sm text-verde-deep">Resto</h2>
        <div className="mt-3 flex flex-col gap-2">
          {resolved.map((u) => (
            <div
              key={u.id}
              className="flex items-center justify-between gap-3 rounded-xl border border-line bg-surface p-3"
            >
              <div className="min-w-0">
                <div className="truncate text-sm font-semibold">{u.display_name}</div>
                <div className="truncate text-xs text-text-soft">{u.email}</div>
              </div>
              <span
                className={`shrink-0 rounded-full px-2.5 py-1 text-[11px] font-semibold ${
                  u.status === "approved"
                    ? "bg-verde text-[var(--hero-text)]"
                    : "bg-rosa text-white"
                }`}
              >
                {u.status === "approved" ? "Aprobado" : "Rechazado"}
                {u.role === "admin" ? " · Admin" : ""}
              </span>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
