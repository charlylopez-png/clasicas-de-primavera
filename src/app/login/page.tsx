"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";

export default function LoginPage() {
  const router = useRouter();
  const params = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "No se pudo iniciar sesión.");
        return;
      }
      const next = params.get("next");
      router.push(
        data.status === "approved" ? next ?? "/mi-equipo" : "/pendiente"
      );
      router.refresh();
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto max-w-sm px-5 py-14">
      <h1 className="text-2xl text-verde-deep">Entrar</h1>
      <p className="mt-2 text-sm text-text-soft">
        Accede con tu email y contraseña para elegir tu equipo.
      </p>

      <form onSubmit={onSubmit} className="mt-6 flex flex-col gap-4">
        <Field label="Email">
          <input
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full rounded-lg border border-line bg-bg px-3 py-2 text-sm"
          />
        </Field>
        <Field label="Contraseña">
          <input
            type="password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full rounded-lg border border-line bg-bg px-3 py-2 text-sm"
          />
        </Field>

        {error && <p className="text-sm text-rosa">{error}</p>}

        <button
          type="submit"
          disabled={loading}
          className="mt-2 rounded-full bg-verde px-5 py-2.5 font-display text-xs uppercase tracking-wide text-[var(--hero-text)] disabled:opacity-60"
        >
          {loading ? "Entrando…" : "Entrar"}
        </button>
      </form>

      <p className="mt-5 text-sm text-text-soft">
        ¿Aún no tienes cuenta?{" "}
        <Link href="/signup" className="text-verde underline">
          Crear cuenta
        </Link>
      </p>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="flex flex-col gap-1 text-sm">
      <span className="font-display text-[11px] uppercase tracking-wide text-text-soft">
        {label}
      </span>
      {children}
    </label>
  );
}
