# FitTrack

FitTrack is a native iPhone and Apple Watch fitness app for strength training and nutrition tracking. It is written in Swift and SwiftUI, and the whole user interface is in French.

* **iPhone (iOS 18+, built and tested for iPhone 15 / iOS 26):** dashboard, 5-day program, live workouts with rest timer, exercise library, history and personal records, food journal (search, barcode, meal photo, manual entry), halal-aware food information, progress charts, Apple Health.
* **Apple Watch (watchOS 11+, built and tested for Series 11 / watchOS 26):** program, live workout with heart rate and calories, set/rep/weight tracking with the Digital Crown, rest timer, works without the iPhone and syncs when it is back in range.

No third-party dependencies. No paid service is required.

---

## 1. Install on your iPhone and Apple Watch (free Apple ID)

You need a Mac with **Xcode 26** or later (free on the Mac App Store), your iPhone, a USB cable, and your Apple ID.

1. **Get the project.** Download `FITTRACK.zip` (see *Download* below) and double-click it to unzip.
2. **Open it.** Double-click `FitTrack.xcodeproj`. Xcode opens.
3. **Add your Apple ID to Xcode** (first time only): menu **Xcode › Settings… › Accounts**, click **+**, choose **Apple ID** and sign in.
4. **Select your team for the iPhone app:**
   1. In the left column, click the blue **FitTrack** project icon at the top.
   2. Under **TARGETS**, click **FitTrack**, then open the **Signing & Capabilities** tab.
   3. Make sure **Automatically manage signing** is checked.
   4. In **Team**, choose your name (**Personal Team**).
5. **Do the same for the Watch app:** under **TARGETS**, click **FitTrackWatch** and choose the same **Team**.
6. **Prepare the iPhone** (first time only):
   1. Plug the iPhone into the Mac and unlock it. Tap **Trust** if asked.
   2. On the iPhone, open **Réglages › Confidentialité et sécurité › Mode développeur**, turn it on, and restart when asked.
   3. Do the same on the Apple Watch: **Réglages › Confidentialité et sécurité › Mode développeur**.
7. **Run:**
   1. At the top of the Xcode window, choose the **FitTrack** scheme.
   2. Choose your iPhone as the destination.
   3. Click the ▶︎ button. The first build takes a few minutes.
8. **Trust the developer** (first time only): on the iPhone, open **Réglages › Général › VPN et gestion de l'appareil**, tap your Apple ID, then **Faire confiance**. Open FitTrack again.
9. **Apple Watch:** the Watch app installs with the iPhone app. If it doesn't appear, open the **Watch** app on the iPhone, go to **Mon Apple Watch**, scroll to **FitTrack** and tap **Installer**.

> **Free Apple ID limitation:** apps signed with a free account stop opening after **7 days**. To renew, plug in the iPhone and press ▶︎ again in Xcode. Your data is kept.
>
> **If Xcode says the bundle identifier is not available:** in **Signing & Capabilities**, change *Bundle Identifier* from `com.sabri68.fittrack` to something unique, for example `com.sabri68.fittrack2`. Then change the Watch app to the same prefix plus `.watchkitapp`.

---

## 2. Features and status

Status labels used below:

* ✅ **Verified in CI:** built and exercised by automated tests on real Xcode with the iPhone 15 and Apple Watch Series 11 simulators.
* 📱 **Device test needed:** implemented with Apple's real APIs, but it needs real hardware or an account that the simulator lacks.
* ☁️ **External setup:** implemented, but needs the paid Apple Developer Program.

| Feature | Status |
|---|---|
| French interface, French number/date formats | ✅ |
| Onboarding with the initial profile (male, 24, 177 cm, 77 kg, beginner, recomposition, 5 sessions/week, halal) | ✅ UI test |
| Nutrition targets (Mifflin-St Jeor, activity, goal) | ✅ unit tests |
| 5-day beginner program (also 3 and 4 days); edit, reorder, add and remove exercises | ✅ |
| Live workout: start, pause, resume, finish, abandon, edit weight and reps, add and remove sets and exercises | ✅ UI test |
| Rest timer (keeps running in the background, local notification at the end) | ✅ timer UI test · 📱 notification |
| Workout saved after every set; recovery after the app is killed | ✅ UI test (kills the app mid-workout) |
| Progressive overload suggestions, personal records, estimated 1RM | ✅ unit tests |
| Exercise library (38 exercises, steps, tips, muscles, video search link) | ✅ |
| Food journal by meal, edit/delete, daily totals | ✅ UI test |
| Built-in database of common foods (offline) | ✅ |
| Open Food Facts search and barcode lookup | ✅ parsing tests · 📱 live network |
| Barcode scanning with the camera (VisionKit) | 📱 the simulator has no camera |
| Meal photo recognition (on-device Apple Vision classifier, mapped to 220+ foods) | ✅ mapping tests · 📱 real photos |
| Manual nutrition entry with validation | ✅ UI test |
| Halal information: declared label, potentially non-halal ingredients, "depends on origin", unknown | ✅ unit tests |
| Progress: weight, frequency, volume, strength, records, nutrition averages | ✅ screen opened in UI test |
| Apple Health: read steps/energy/exercise/weight/heart rate; write workouts, weight, nutrition | 📱 needs your permission on device |
| Apple Watch app: program, workout, sets, Digital Crown, rest timer, heart rate, Health workout | ✅ watch UI test · 📱 heart rate on wrist |
| iPhone ↔ Watch sync (WatchConnectivity, offline queue, duplicate-safe import) | ✅ payload and import tests · 📱 paired devices |
| Private iCloud sync (SwiftData + CloudKit) | ☁️ code compiled in CI, switched off by default |

### Food photo recognition: how it works and its limits

Photos are analysed **on the iPhone** by Apple's built-in image classifier (Vision). Nothing is uploaded and no API key is needed. The classifier recognises the type of food (for example "pâtes", "salade", "banane") and FitTrack offers the matching foods. You confirm the exact food and the quantity yourself, because portion size cannot be measured from a photo.

The more advanced generative recognition (Apple Intelligence) is not available on the standard iPhone 15.

### Halal information

FitTrack never labels a product halal on its own:

* **"Déclaré halal (non vérifié)"**: the Open Food Facts product page carries a halal label. That label is user-contributed, so check the certification logo on the pack.
* **"Potentiellement non halal"**: pork, alcohol, gelatin, carmine or similar ingredients were detected. These products are hidden from search results when the halal preference is on, and you can reveal them.
* **"Selon provenance"**: meat or poultry, where the halal status depends on slaughter and certification.
* **"Aliment brut, généralement halal"** and **"Végétal, sans alcool détecté"**: raw foods or plant-based products. These are not certifications.
* **"Statut halal inconnu"**: not enough information.

---

## 3. Enable private iCloud sync (optional, paid account)

iCloud sync requires the **Apple Developer Program (99 €/year)**. Apple does not allow iCloud for free accounts. The code is already in the app and was compiled in CI. Without iCloud, data stays on the iPhone and the Watch syncs directly with it.

1. Join the Apple Developer Program at <https://developer.apple.com/programs/> and wait for the confirmation email.
2. In Xcode, select your paid team in **Signing & Capabilities** for **FitTrack** and **FitTrackWatch**.
3. At the top of the Xcode window, switch the scheme from **FitTrack** to **FitTrack iCloud**.
4. Open **TARGETS › FitTrack › Signing & Capabilities**. Under **iCloud**, check the container **iCloud.com.sabri68.fittrack**. If it is missing or red, click **+** to create it with that name, then click the ↻ refresh button.
5. Press ▶︎. The app now stores its data in your private iCloud database. **Profil › Synchronisation iCloud** shows **Activée**.

How it works: SwiftData mirrors every record to your private CloudKit database, and changes made offline are uploaded when the network returns. Conflicts are resolved per record (the most recent change wins). FitTrack also removes duplicates by their unique identifier at launch. Your data stays in your private database, which only your Apple ID can read.

---

## 4. Architecture

```
Shared/          Compiled into both the iPhone and Watch targets
  Models/        SwiftData models (CloudKit-compatible: defaults, optional relationships, uuid)
  Domain/        Nutrition maths, strength maths, halal analysis, French formatting
  Catalog/       Exercise library, 3/4/5-day programs
  Persistence/   ModelContainer factory (local or CloudKit) and DataService (all data operations)
  Sync/          Codable WatchConnectivity payloads
iOS/             iPhone app (MVVM-style: SwiftUI views + @Observable services)
  App/           Entry point, AppModel (dependency container), root navigation
  Features/      Dashboard, Workout, Nutrition, Progress, Profile, Onboarding
  Services/      HealthKit, Open Food Facts, barcode scanner, camera, photo recognition, watch sync
  DesignSystem/  Theme and reusable components
Watch/           Apple Watch app (HKWorkoutSession, WatchConnectivity, SwiftUI)
Tests/           Unit tests (iOS + watchOS) and UI tests (iOS + watchOS)
project.yml      XcodeGen specification; FitTrack.xcodeproj is generated from it by CI
docs/            Plan and screenshots captured by the UI tests
```

Key choices:

* **SwiftData** for persistence: native, works offline, and syncs through CloudKit when enabled.
* **WatchConnectivity**:
  * The program goes from the iPhone to the Watch with `updateApplicationContext`.
  * Finished workouts go from the Watch to the iPhone with `transferUserInfo`. The system queues these until the iPhone is reachable, and the iPhone imports them only once (by `uuid`).
* **Crash safety:** every validated set is saved immediately, and timers are based on dates, not on counting ticks. On the Watch, the HealthKit workout session keeps the app running and can be recovered by the system.
* **Concurrency:** async/await and `@MainActor` view models and services, in Swift 5 language mode.

## 5. Build and test verification

The development machine for this project was Linux, so every build and test runs on **GitHub Actions macOS runners** with real Xcode (`.github/workflows/ci.yml`). Each push does the following:

1. Generates the Xcode project with XcodeGen.
2. Builds the iPhone app (with the embedded Watch app), the Watch app, and the iCloud variant.
3. Checks that the Watch app is embedded with the right companion identifier.
4. Runs unit and UI tests on an **iPhone 15** simulator and on an **Apple Watch Series 11 (46 mm)** simulator.
5. Commits the regenerated `FitTrack.xcodeproj` and the UI-test screenshots (`docs/screenshots/`).
6. Publishes `FITTRACK.zip` as a build artifact.

## Download

From the repository page: **Actions › latest green run › Artifacts › FITTRACK-project**. You can also use **Code › Download ZIP** on the branch.

## Data sources and licences

* Food products: [Open Food Facts](https://world.openfoodfacts.org), Open Database License (ODbL).
* Generic foods: rounded averages from public food-composition tables (Ciqual/USDA).
* Nutrition targets are estimates and are not medical advice.
