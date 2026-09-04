"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";

export default function SignupPage() {
  const router = useRouter();
  const [displayName, setDisplayName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch("/api/auth/signup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ displayName, email, password }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "No se pudo crear la cuenta.");
        return;
      }
      router.push(data.status === "approved" ? "/mi-equipo" : "/pendiente");
      router.refresh();
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto max-w-sm px-5 py-14">
      <h1 className="text-2xl text-verde-deep">Crear cuenta</h1>
      <p className="mt-2 text-sm text-text-soft">
        Apúntate a la porra. El organizador tiene que aprobar tu cuenta antes
        de que puedas elegir tu equipo.
      </p>

      <form onSubmit={onSubmit} className="mt-6 flex flex-col gap-4">
        <Field label="Cómo te llamamos">
          <input
            type="text"
            required
            maxLength={60}
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            className="w-full rounded-lg border border-line bg-bg px-3 py-2 text-sm"
          />
        </Field>
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
            minLength={8}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full rounded-lg border border-line bg-bg px-3 py-2 text-sm"
          />
          <span className="text-[11px] text-text-soft">Mínimo 8 caracteres.</span>
        </Field>

        {error && <p className="text-sm text-rosa">{error}</p>}

        <button
          type="submit"
          disabled={loading}
          className="mt-2 rounded-full bg-amarillo px-5 py-2.5 font-display text-xs uppercase tracking-wide text-on-accent hover:bg-gold disabled:opacity-60"
        >
          {loading ? "Creando…" : "Crear cuenta"}
        </button>
      </form>

      <p className="mt-5 text-sm text-text-soft">
        ¿Ya tienes cuenta?{" "}
        <Link href="/login" className="text-verde underline">
          Entrar
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
