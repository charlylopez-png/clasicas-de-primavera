import type { Metadata } from "next";
import { Oswald, Karla } from "next/font/google";
import "./globals.css";
import { getSession } from "@/lib/auth";
import SiteHeader from "@/components/site-header";

const oswald = Oswald({
  variable: "--font-oswald",
  weight: ["400", "500", "600", "700"],
  subsets: ["latin"],
});

const karla = Karla({
  variable: "--font-karla",
  weight: ["400", "500", "600", "700"],
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "UKT — Porra de las Clásicas de Primavera",
  description:
    "Udaberriko Klasiko Txirrindulariak: la porra ciclista de las clásicas de primavera entre amigos.",
};

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await getSession();

  return (
    <html
      lang="es"
      className={`${oswald.variable} ${karla.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-bg text-text">
        <SiteHeader session={session} />
        <main className="flex-1">{children}</main>
      </body>
    </html>
  );
}
