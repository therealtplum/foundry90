"use client";

import ReactMarkdown from "react-markdown";

interface Props {
  markdown: string;
}

export function MarkdownCard({ markdown }: Props) {
  return (
    <article className="prose prose-invert prose-sm max-w-none rounded-lg border border-slate-800 bg-slate-900/60 px-5 py-4">
      <ReactMarkdown>{markdown}</ReactMarkdown>
    </article>
  );
}
