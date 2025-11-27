// apps/web/app/layout.tsx
import type { Metadata } from "next";
import "../styles/globals.css";
import ThemeToggle from "../components/ThemeToggle";

export const metadata: Metadata = {
  title: "Foundry90",
  description: "Focused, end-to-end data capstone builds.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="f90-body">
        {children}
        <ThemeToggle />
      </body>
    </html>
  );
}