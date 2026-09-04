import type { Metadata, Viewport } from "next";
import { Oswald, Nunito, Archivo_Black } from "next/font/google";
import "./globals.css";
import { getSession } from "@/lib/auth";
import SiteHeader from "@/components/site-header";

const oswald = Oswald({
  variable: "--font-oswald",
  weight: ["400", "500", "600", "700"],
  subsets: ["latin"],
});

const nunito = Nunito({
  variable: "--font-nunito",
  weight: ["400", "600", "700"],
  subsets: ["latin"],
});

const archivoBlack = Archivo_Black({
  variable: "--font-archivo",
  weight: "400",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "UKT — Porra de las Clásicas de Primavera",
  description:
    "Udaberriko Klasiko Txirrindulariak: la porra ciclista de las clásicas de primavera entre amigos.",
  manifest: "/manifest.json",
  icons: {
    icon: [
      { url: "/ukt-identity/png/ukt-icon-32-favicon.png", sizes: "32x32", type: "image/png" },
      { url: "/ukt-identity/png/ukt-icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/ukt-identity/png/ukt-icon-512-cobble.png", sizes: "512x512", type: "image/png" },
    ],
    apple: [
      { url: "/ukt-identity/png/ukt-icon-180-apple.png", sizes: "180x180", type: "image/png" },
    ],
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "UKT",
  },
};

export const viewport: Viewport = {
  themeColor: "#0d2c20",
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
      className={`${oswald.variable} ${nunito.variable} ${archivoBlack.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-bg text-text">
        <SiteHeader session={session} />
        <main className="flex-1">{children}</main>
      </body>
    </html>
  );
}
