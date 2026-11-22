# Changelog

All notable changes to FitTrack are documented here. Dates are in YYYY-MM-DD format.

## [1.0.0] – 2026-11-22

First complete version of the iPhone and Apple Watch apps.

### iPhone
- French onboarding pre-filled with the initial profile, nutrition target summary and an optional Apple Health connection.
- Dashboard: calories eaten and remaining, macronutrient bars, Health activity (steps, active energy, exercise minutes), next program day, weekly training statistics and streak, weight progress toward the goal, banner to resume an interrupted workout.
- Strength training:
  - Beginner programs for 3, 4 or 5 days, which can be edited (exercises, sets, repetitions, rest, starting weight, order).
  - Library of 38 exercises with muscles, steps, tips and a video search link.
  - Live workout: pause and resume, editable weight and reps, add or remove sets and exercises, rest timer with ±15 s and a notification, summary with new records.
  - Progressive overload suggestions (double progression), personal records, estimated 1RM, history with notes.
  - Every validated set is saved immediately, and an interrupted workout is restored at the next launch.
- Nutrition:
  - Food journal by meal (breakfast, lunch, dinner, snacks) with daily totals.
  - Four ways to add a food:
    - search (built-in common foods plus Open Food Facts);
    - camera barcode scanning (VisionKit), with manual code entry as a fallback;
    - meal photo recognition with Apple's on-device Vision classifier;
    - validated manual entry.
  - Serving sizes and quick quantities; editing and deleting entries.
  - Halal information that never claims a certification: declared label, potentially non-halal ingredients, depends on origin, unknown. Potentially non-halal products are hidden when the halal preference is on, and can be revealed.
- Progress: weight chart with target, weekly frequency against goal, weekly volume, strength progression (estimated 1RM), personal records, calorie and macronutrient averages over 4 weeks, 3 months or 1 year.
- Profile: personal data, goal, frequency, halal preference, custom calorie target, program regeneration, Apple Health / Apple Watch / iCloud status, data reset.
- Apple Health:
  - Reads steps, active energy, exercise minutes, weight and heart rate.
  - Writes strength workouts, body weight and nutrition (energy, protein, carbs, fat), and removes the nutrition samples when an entry is deleted.

### Apple Watch
- Standalone program (works without the iPhone) that is replaced by the iPhone's program when it arrives.
- Live workout with HKWorkoutSession: heart rate, active energy, duration, pause/resume, saved to Apple Health.
- Set tracking with the Digital Crown (weight in 0.5 kg steps, repetitions), next and previous exercise, rest timer with haptics.
- Finished workouts are queued for the iPhone (`transferUserInfo`) and re-sent if never confirmed. The iPhone imports each one only once.
- Workout recovery when watchOS relaunches the app.

### Infrastructure
- XcodeGen project with iOS, watchOS, unit-test and UI-test targets, plus a "FitTrack iCloud" scheme with CloudKit entitlements.
- SwiftData models that are compatible with CloudKit. Private iCloud sync is compiled in and switched on by the iCloud scheme (paid account required).
- GitHub Actions on macOS with real Xcode:
  - builds iOS, watchOS and the iCloud variant;
  - runs unit and UI tests on the iPhone 15 and Apple Watch Series 11 simulators;
  - captures screenshots;
  - commits the generated project;
  - produces a ZIP artifact.
