import bcrypt from "bcryptjs";
import { randomInt } from "crypto";
import { SignJWT, jwtVerify } from "jose";
import { cookies } from "next/headers";

export const SESSION_COOKIE = "ukt_session";

const encodedSecret = () => {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error(
      "Falta la variable de entorno JWT_SECRET (Vercel → Project → Settings → Environment Variables)."
    );
  }
  return new TextEncoder().encode(secret);
};

export type SessionPayload = {
  userId: string;
  email: string;
  displayName: string;
  role: "admin" | "participant";
  status: "pending" | "approved" | "rejected";
  // Solo para mostrar/ocultar el enlace "Corredores" en el menú: el
  // permiso real siempre se reverifica contra la base de datos en
  // /corredores y su API, porque este campo puede quedar desactualizado
  // durante los 30 días de vida del token si el admin cambia el Sanedrín.
  sanedrin: boolean;
};

export async function hashPassword(password: string) {
  return bcrypt.hash(password, 10);
}

export async function verifyPassword(password: string, hash: string) {
  return bcrypt.compare(password, hash);
}

// Para "Restablecer contraseña" desde /admin: una contraseña nueva y
// legible (sin caracteres que se confunden fácilmente al dictarla o
// pasarla por WhatsApp: sin 0/O, 1/l/I). Se genera aquí y solo se
// muestra una vez en el momento de crearla — no se guarda en ningún
// sitio en texto plano, solo su hash.
const PASSWORD_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";

export function generateRandomPassword(length = 10) {
  let out = "";
  for (let i = 0; i < length; i++) {
    out += PASSWORD_CHARS[randomInt(PASSWORD_CHARS.length)];
  }
  return out;
}

export async function createSessionToken(payload: SessionPayload) {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(encodedSecret());
}

export async function verifySessionToken(
  token: string
): Promise<SessionPayload | null> {
  try {
    const { payload } = await jwtVerify(token, encodedSecret());
    return payload as unknown as SessionPayload;
  } catch {
    return null;
  }
}

export async function getSession(): Promise<SessionPayload | null> {
  const store = await cookies();
  const token = store.get(SESSION_COOKIE)?.value;
  if (!token) return null;
  return verifySessionToken(token);
}

export async function setSessionCookie(payload: SessionPayload) {
  const token = await createSessionToken(payload);
  const store = await cookies();
  store.set(SESSION_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 30,
  });
}

export async function clearSessionCookie() {
  const store = await cookies();
  store.delete(SESSION_COOKIE);
}

// "Actuar como": deja que el admin entre temporalmente en la sesión de
// otro jugador (típicamente uno "manual", sin cuenta propia) para hacer
// por él los mismos pasos que haría cualquiera — Equipo Base, Last Draft,
// elección del Mundial… — sin tener que construir una pantalla aparte
// para cada cosa. La sesión de admin no se pierde: se guarda en una
// segunda cookie mientras dura la suplantación, y "Volver a mi cuenta" la
// restaura.
export const IMPERSONATE_COOKIE = "ukt_admin_backup";

export async function startImpersonation(targetPayload: SessionPayload) {
  const store = await cookies();
  const adminToken = store.get(SESSION_COOKIE)?.value;
  if (adminToken) {
    store.set(IMPERSONATE_COOKIE, adminToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      // Misma duración que una sesión normal: si caducara antes que la
      // suplantación, el admin se quedaría atrapado en la otra cuenta sin
      // aviso (la barra de "Actuando como" desaparecería sin más).
      maxAge: 60 * 60 * 24 * 30,
    });
  }
  await setSessionCookie(targetPayload);
}

// Devuelve la sesión de admin guardada, o null si no se estaba
// suplantando a nadie (no toca cookies).
export async function getImpersonationAdmin(): Promise<SessionPayload | null> {
  const store = await cookies();
  const token = store.get(IMPERSONATE_COOKIE)?.value;
  if (!token) return null;
  return verifySessionToken(token);
}

// Restaura la sesión de admin guardada. Devuelve false si no había
// ninguna que restaurar (por ejemplo, la cookie caducó a las 4h).
export async function stopImpersonation(): Promise<boolean> {
  const store = await cookies();
  const adminToken = store.get(IMPERSONATE_COOKIE)?.value;
  store.delete(IMPERSONATE_COOKIE);
  if (!adminToken) return false;

  store.set(SESSION_COOKIE, adminToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 24 * 30,
  });
  return true;
}
