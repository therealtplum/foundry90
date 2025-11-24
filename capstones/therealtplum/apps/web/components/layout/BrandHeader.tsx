"use client";

import Link from "next/link";
import Image from "next/image";

export function BrandHeader() {
  return (
    <header className="w-full border-b border-f90/40 bg-black/40 backdrop-blur-md sticky top-0 z-40">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
        <Link href="/" className="flex items-center gap-3">
          <div className="relative h-9 w-9">
            <Image
              src="/foundry90_logo.svg"
              alt="Foundry90 logo"
              fill
              sizes="36px"
              priority
            />
          </div>
          <div className="flex flex-col leading-tight">
            <span className="text-sm font-semibold tracking-[0.22em] text-f90-green uppercase">
              Foundry90
            </span>
            <span className="text-xs text-f90-muted">
              90-day product capstones
            </span>
          </div>
        </Link>

        <nav className="flex items-center gap-6 text-xs font-medium text-f90-muted">
          <Link href="/capstones" className="hover:text-f90-green transition-colors">
            Capstones
          </Link>
          <Link href="/about" className="hover:text-f90-green transition-colors">
            About
          </Link>
          <Link href="/contact" className="hover:text-f90-green transition-colors">
            Contact
          </Link>
        </nav>
      </div>
    </header>
  );
}