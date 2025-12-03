import fs from "fs";
import path from "path";
import { LocHistoryChart } from "@/components/LocHistoryChart";
import { LanguagePills } from "@/components/LanguagePills";

export default function LocPage() {
  const filePath = path.join(
    process.cwd(),
    "..",
    "..", 
    "ops",
    "data",
    "loc_history.json"
  );

  // Optional sanity check while debugging:
  // console.log("LOC FILE PATH:", filePath);

  const raw = fs.readFileSync(filePath, "utf8");
  const snapshots = JSON.parse(raw);

  // Languages to show in pills (matching chart languages, with "Bourne Shell" mapped to "Shell")
  const languages = ["Rust", "Python", "TypeScript", "Swift", "CSS", "Shell"];

  return (
    <main className="f90-page">
      <section style={{ marginBottom: "56px" }}>
        <h1 className="f90-hero-title">
          <span>Foundry90 LOC History</span>
        </h1>
      </section>
      <div className="f90-section">
        <LocHistoryChart snapshots={snapshots} />
        <LanguagePills languages={languages} />
      </div>
    </main>
  );
}

