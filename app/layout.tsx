import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import "./globals.css";

const gilroy = localFont({
  src: [
    {
      path: "./fonts/gilroy-regular.otf",
      weight: "400",
      style: "normal",
    },
    {
      path: "./fonts/gilroy-bold.ttf",
      weight: "700",
      style: "normal",
    },
    {
      path: "./fonts/gilroy-black.ttf",
      weight: "900",
      style: "normal",
    },
    {
      path: "./fonts/gilroy-extra-bold-italic.ttf",
      weight: "800",
      style: "italic",
    },
  ],
  variable: "--font-gilroy",
  display: "swap",
  fallback: ["Arial", "Helvetica", "sans-serif"],
  adjustFontFallback: "Arial",
});

export const metadata: Metadata = {
  title: "Ortusolis Monitor",
  description: "Consulta de registros de aplicações Ortusolis.",
};

export const viewport: Viewport = {
  themeColor: "#12252b",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="pt-BR"
      className={`${gilroy.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
