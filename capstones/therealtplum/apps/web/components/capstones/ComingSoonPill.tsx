// apps/web/components/capstones/ComingSoonPill.tsx
"use client";

import { useState, FormEvent } from "react";

type SubmissionState = "idle" | "submitting" | "success" | "error";

export default function ComingSoonPill() {
  const [email, setEmail] = useState("");
  const [state, setState] = useState<SubmissionState>("idle");
  const [message, setMessage] = useState("");

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();

    if (!email.trim()) {
      setMessage("Please enter your email address");
      setState("error");
      return;
    }

    setState("submitting");
    setMessage("");

    try {
      const response = await fetch("/api/notify", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ email }),
      });

      const data = await response.json();

      if (response.ok) {
        setState("success");
        setMessage(data.message || "Thanks! We'll notify you when the project launches.");
        setEmail("");
      } else {
        setState("error");
        setMessage(data.error || "Something went wrong. Please try again.");
      }
    } catch (error) {
      setState("error");
      setMessage("Network error. Please check your connection and try again.");
    }
  };

  return (
    <div className="f90-coming-soon-pill">
      <div className="f90-coming-soon-header">
        <span className="f90-coming-soon-label">COMING SOON</span>
      </div>

      <div className="f90-coming-soon-body">
        {state === "success" ? (
          <div className="f90-coming-soon-success">
            <div className="f90-coming-soon-success-icon">✓</div>
            <p className="f90-coming-soon-message">{message}</p>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="f90-coming-soon-form">
            <div className="f90-coming-soon-form-group">
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="your@email.com"
                className="f90-coming-soon-input"
                disabled={state === "submitting"}
                required
                autoComplete="email"
              />
              <button
                type="submit"
                className="f90-coming-soon-submit"
                disabled={state === "submitting"}
              >
                {state === "submitting" ? "..." : "Notify Me"}
              </button>
            </div>
            {state === "error" && message && (
              <p className="f90-coming-soon-error">{message}</p>
            )}
          </form>
        )}
      </div>
    </div>
  );
}

