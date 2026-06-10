// Einmaliges Backfill: schreibt `kickoff` (Timestamp) in alle bestehenden Bets,
// die noch kein kickoff-Feld haben. Quelle: API-Football (echter Anpfiff je fixtureId).
//
// MUSS laufen, BEVOR die verschaerfte Firestore-Regel (kickoff <= request.time) deployt wird,
// sonst verschwinden fremde historische Tipps aus Ranglisten/Punkten.
//
// Voraussetzungen:
//   - Node 20+
//   - npm i firebase-admin            (im scripts/-Ordner)
//   - Service-Account-JSON aus Firebase Console (Projekteinstellungen -> Dienstkonten)
//
// Aufruf:
//   GOOGLE_APPLICATION_CREDENTIALS=./service-account.json \
//   API_FOOTBALL_KEY=dein_key \
//   node backfill-kickoff.mjs            # Dry-Run (nur Ausgabe)
//   ... DRY_RUN=0 node backfill-kickoff.mjs   # Schreibt wirklich

import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

const API_KEY  = process.env.API_FOOTBALL_KEY;
const DRY_RUN  = process.env.DRY_RUN !== "0";
const BASE_URL = "https://v3.football.api-sports.io";

if (!API_KEY) { console.error("❌ API_FOOTBALL_KEY fehlt"); process.exit(1); }

initializeApp({ credential: applicationDefault() }); // nutzt GOOGLE_APPLICATION_CREDENTIALS
const db = getFirestore();

// 1. Alle Bets ueber alle Communities laden (collectionGroup), nur ohne kickoff.
const snap = await db.collectionGroup("bets").get();
const todo = snap.docs.filter((d) => d.get("kickoff") == null);
console.log(`Bets gesamt: ${snap.size} | ohne kickoff: ${todo.length}`);
if (todo.length === 0) { console.log("✅ Nichts zu tun."); process.exit(0); }

// 2. Distinkte fixtureIds sammeln und Anpfiff-Zeiten holen (max 20 ids/Call).
const fixtureIds = [...new Set(todo.map((d) => d.get("fixtureId")).filter((x) => x != null))];
const kickoffById = new Map();

for (let i = 0; i < fixtureIds.length; i += 20) {
  const batch = fixtureIds.slice(i, i + 20);
  const url = `${BASE_URL}/fixtures?ids=${batch.join("-")}`;
  const res = await fetch(url, { headers: { "x-apisports-key": API_KEY } });
  const json = await res.json();
  for (const item of json.response ?? []) {
    const id = item?.fixture?.id;
    const date = item?.fixture?.date; // ISO8601
    if (id != null && date) kickoffById.set(id, new Date(date));
  }
  console.log(`  fixtures ${i + batch.length}/${fixtureIds.length} geladen`);
  await new Promise((r) => setTimeout(r, 300)); // API-Rate-Limit schonen
}

// 3. In Batches (<=500) schreiben.
//    Fallback fuer Bets ohne API-Datum (alte Saison): createdAt nutzen, ABER nur wenn
//    eindeutig in der Vergangenheit (> 2 Tage alt) -> Match sicher angepfiffen, kein Leak.
const TWO_DAYS = 2 * 86400 * 1000;
let written = 0, skipped = 0, batch = db.batch(), inBatch = 0;
for (const doc of todo) {
  let ko = kickoffById.get(doc.get("fixtureId"));
  if (!ko) {
    const created = doc.get("createdAt")?.toDate?.();
    if (created && Date.now() - created.getTime() > TWO_DAYS) {
      ko = created; // altes, sicher angepfiffenes Spiel
    } else {
      skipped++; continue; // kommendes/junges Spiel ohne API-Datum -> nicht leaken
    }
  }
  if (DRY_RUN) { written++; continue; }
  batch.update(doc.ref, { kickoff: Timestamp.fromDate(ko) });
  written++; inBatch++;
  if (inBatch === 500) { await batch.commit(); batch = db.batch(); inBatch = 0; }
}
if (!DRY_RUN && inBatch > 0) await batch.commit();

console.log(`${DRY_RUN ? "[DRY-RUN] " : ""}geschrieben: ${written} | uebersprungen: ${skipped}`);
if (skipped > 0) console.warn("⚠️ Uebersprungene Bets (kein API-Datum, < 2 Tage alt) erneut laufen lassen, sobald das Spiel angepfiffen ist.");
