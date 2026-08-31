# Pattern Sizer — Garment Measurement QA App

A Flutter app that digitizes the paper "Measurement Findings
Summary" tally sheet used for garment sample/pilot-run QA.

## What it does

1. **Login** — email/password via Firebase Auth.
2. **New Job** — enter Style, PO, Pattern No., Sample Unit,
   Size Set/Pilot Run, Date, and a global tolerance (e.g. ± 1/4").
3. **Measurement Entry** — pick a measurement point (Waist,
   Seat, Thigh, Inseam, Front Rise, Back Rise, Bottom, Out Seam,
   Knee) and tap the deviation value (-1" to +1" in 1/8" steps)
   for each piece measured. Every tap is written to Firestore
   immediately, so the job stays in sync across devices/users.
4. **Summary** — a digital replica of the paper tally grid for
   every measurement point, plus computed stats: sample count,
   mean deviation, and how many pieces fall within the job's
   tolerance (pass/fail).
5. **Job History** — list of past jobs; tap to keep measuring,
   long-press to jump straight to the summary.

## Data model (Firestore)

```
jobs/{jobId}
  style, po, patternNo, sampleUnit, sizeSet, date,
  tolerance, createdBy, createdAt

jobs/{jobId}/readings/{readingId}
  measurementPoint, deviation, recordedAt
```

## Setup

1. Install Flutter (3.x) and the FlutterFire CLI.
2. From the project root:
   ```
   flutter pub get
   flutterfire configure
   ```
   This generates `lib/firebase_options.dart` and wires up your
   Firebase project (Android/iOS/Web as needed).
3. In `lib/main.dart`, pass the generated options to
   `Firebase.initializeApp(options: ...)` (a comment marks
   exactly where).
4. In the Firebase console, enable **Email/Password** under
   Authentication, and create a **Firestore** database.
5. Deploy `firestore.rules` (starter rules — any signed-in user
   can read/write all jobs; tighten later if you need per-team
   restrictions):
   ```
   firebase deploy --only firestore:rules
   ```
6. Run the app:
   ```
   flutter run
   ```

## Things you'll likely want to add next

- Editing/deleting a single reading (currently append-only from
  the entry screen; `FirestoreService.deleteReading` already
  exists for this).
- Exporting a job summary as PDF/Excel to match the original
  paper form for handoff to other teams.
- Role-based access (e.g. QC staff can enter readings, managers
  can also edit tolerances) — would mean tightening
  `firestore.rules` beyond the current "any signed-in user".
- Editable measurement-point list per style, if that ever
  becomes necessary (currently intentionally fixed, matching
  your paper form).
