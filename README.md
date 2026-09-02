# UKT — Udaberriko Klasiko Txirrindulariak

Porra ciclista de las Clásicas de Primavera. Next.js (App Router) + Tailwind v4,
desplegada en Vercel, con base de datos Postgres (Vercel Storage / Neon).

## Qué hay ya

- Diseño e identidad visual UKT (verde/amarillo/rosa, Oswald + Karla), la misma
  que el reglamento en PDF y la página móvil.
- Cuentas de usuario propias: email + contraseña (sin servicios externos de login).
- Alta con aprobación manual: quien se registra queda **pendiente** hasta que
  el admin lo aprueba o rechaza desde `/admin`.
- El email definido en `ADMIN_EMAIL` se convierte automáticamente en
  administrador (aprobado) al registrarse.
- Páginas públicas: inicio, reglamento y calendario de las 12 clásicas con
  sus logos oficiales.
- `db/schema.sql` con el esquema completo: usuarios, corredores, carreras,
  equipo base, last draft, resultados y duelos sprint (listo para que las
  siguientes pantallas —elegir equipo, cargar resultados, clasificación—
  se construyan encima).

## Pendiente (siguiente fase)

- `/mi-equipo`: elegir Equipo Base (6 corredores) y Last Draft por carrera.
- Panel de admin para cargar resultados de cada carrera.
- Cálculo automático de la clasificación general y de los duelos Sprint.
- Cargar el listado real de corredores (nombre + categoría) en la tabla `riders`.

## Desarrollo local

```bash
npm install
cp .env.example .env.local   # y rellena DATABASE_URL / JWT_SECRET
npm run dev
```

Aplica el esquema a la base de datos una vez tengas `DATABASE_URL`:

```bash
psql "$DATABASE_URL" -f db/schema.sql
```

## Despliegue

El proyecto está pensado para desplegarse en Vercel conectado a este
repositorio de GitHub, con una base de datos Postgres añadida desde
**Vercel → Storage** y las variables de entorno (`DATABASE_URL`, `JWT_SECRET`,
`ADMIN_EMAIL`) configuradas en **Project Settings → Environment Variables**.
