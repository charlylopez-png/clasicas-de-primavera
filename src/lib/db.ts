import { neon, type NeonQueryFunction } from "@neondatabase/serverless";

// Vercel's Neon/Postgres integration injects one of these env var names
// depending on how it was added. We accept any of them so setup is forgiving.
function getConnectionString() {
  return (
    process.env.DATABASE_URL ||
    process.env.POSTGRES_URL ||
    process.env.DATABASE_URL_UNPOOLED ||
    process.env.POSTGRES_URL_NON_POOLING
  );
}

let client: NeonQueryFunction<false, false> | null = null;

// Lazy singleton: we must NOT call neon() at module-evaluation time, because
// Next.js evaluates route modules while collecting build metadata — before
// any env vars from a not-yet-connected database are available. Building
// the client on first real query keeps the build green either way and
// gives a clear runtime error if DATABASE_URL is still missing.
function getClient(): NeonQueryFunction<false, false> {
  if (client) return client;
  const connectionString = getConnectionString();
  if (!connectionString) {
    throw new Error(
      "Falta DATABASE_URL (o POSTGRES_URL). Añade la base de datos en Vercel → Storage y conéctala a este proyecto, o defínela en .env.local para desarrollo."
    );
  }
  client = neon(connectionString);
  return client;
}

// Tagged-template proxy so call sites keep writing `sql`...``` unchanged.
export const sql: NeonQueryFunction<false, false> = ((
  strings: TemplateStringsArray,
  ...values: unknown[]
) => getClient()(strings, ...values)) as NeonQueryFunction<false, false>;

export function hasDatabase() {
  return Boolean(getConnectionString());
}
