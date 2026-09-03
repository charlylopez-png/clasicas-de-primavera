import { NextRequest, NextResponse } from "next/server";
import { jwtVerify } from "jose";
import { SESSION_COOKIE } from "@/lib/auth";

// Routes that require an authenticated session at all.
const PROTECTED_PREFIXES = ["/mi-equipo", "/clasificacion", "/admin", "/pendiente", "/corredores"];
const ADMIN_PREFIX = "/admin";
const PUBLIC_AUTH_PATHS = ["/login", "/signup"];

async function readSession(token: string | undefined) {
  if (!token || !process.env.JWT_SECRET) return null;
  try {
    const { payload } = await jwtVerify(
      token,
      new TextEncoder().encode(process.env.JWT_SECRET)
    );
    return payload as {
      role?: string;
      status?: string;
    };
  } catch {
    return null;
  }
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const token = request.cookies.get(SESSION_COOKIE)?.value;
  const session = await readSession(token);

  const isProtected = PROTECTED_PREFIXES.some((p) => pathname.startsWith(p));
  const isAuthPage = PUBLIC_AUTH_PATHS.some((p) => pathname.startsWith(p));

  if (isAuthPage && session && session.status === "approved") {
    return NextResponse.redirect(new URL("/mi-equipo", request.url));
  }

  if (!isProtected) {
    return NextResponse.next();
  }

  if (!session) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("next", pathname);
    return NextResponse.redirect(loginUrl);
  }

  if (pathname.startsWith(ADMIN_PREFIX) && session.role !== "admin") {
    return NextResponse.redirect(new URL("/mi-equipo", request.url));
  }

  if (
    !pathname.startsWith("/pendiente") &&
    session.role !== "admin" &&
    session.status !== "approved"
  ) {
    return NextResponse.redirect(new URL("/pendiente", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/mi-equipo/:path*",
    "/clasificacion/:path*",
    "/admin/:path*",
    "/pendiente/:path*",
    "/corredores/:path*",
    "/login",
    "/signup",
  ],
};
