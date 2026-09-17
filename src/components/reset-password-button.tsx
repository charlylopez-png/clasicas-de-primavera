"use client";

import { useState, useTransition } from "react";

export default function ResetPasswordButton({
  userId,
  displayName,
}: {
  userId: string;
  displayName: string;
}) {
  const [isPending, startTransition] = useTransition();
  const [result, setResult] = useState<{ password: string } | { error: string } | null>(null);
  const [copied, setCopied] = useState(false);

  function reset() {
    const ok = window.confirm(
      `¿Restablecer la contraseña de ${displayName}? La contraseña que tenía dejará de funcionar.`
    );
    if (!ok) return;
    setResult(null);
    setCopied(false);
    startTransition(async () => {
      const res = await fetch(`/api/admin/users/${userId}/reset-password`, {
        method: "POST",
      });
      const data = await res.json().catch(() => null);
      if (!res.ok) {
        setResult({ error: data?.error ?? "No se pudo restablecer la contraseña." });
        return;
      }
      setResult({ password: data.password });
    });
  }

  async function copy(password: string) {
    try {
      await navigator.clipboard.writeText(password);
      setCopied(true);
    } catch {
      // Portapapeles no disponible (por ejemplo, sin HTTPS): el admin
      // puede seleccionar y copiar la contraseña a mano.
    }
  }

  return (
    <div className="flex flex-col items-end gap-1.5">
      <button
        type="button"
        disabled={isPending}
        onClick={reset}
        className="shrink-0 rounded-full border border-line px-3 py-1.5 font-display text-[11px] uppercase tracking-wide text-verde-deep hover:border-verde-deep disabled:opacity-50"
      >
        {isPending ? "Restableciendo…" : "Restablecer contraseña"}
      </button>

      {result && "password" in result && (
        <div className="max-w-[220px] rounded-lg border border-verde-deep/40 bg-verde-deep/10 px-2.5 py-1.5 text-right">
          <p className="text-[10px] leading-tight text-text-soft">
            Nueva contraseña — pásasela ahora, no se volverá a mostrar:
          </p>
          <div className="mt-1 flex items-center justify-end gap-1.5">
            <code className="select-all font-mono text-sm text-verde-deep">
              {result.password}
            </code>
            <button
              type="button"
              onClick={() => copy(result.password)}
              className="shrink-0 text-[11px] text-verde-deep underline underline-offset-2"
            >
              {copied ? "Copiada" : "Copiar"}
            </button>
          </div>
        </div>
      )}
      {result && "error" in result && (
        <p className="max-w-[220px] text-right text-xs text-rosa">{result.error}</p>
      )}
    </div>
  );
}
