import Foundation
import SwiftData

enum Persistence {
    static let schema = Schema([
        UserProfile.self, WeightEntry.self,
        WorkoutTemplate.self, TemplateExercise.self,
        WorkoutSession.self, ExerciseLog.self, SetLog.self,
        FoodEntry.self,
    ])

    /// iCloud container used when private iCloud sync is enabled (requires a paid Apple Developer account).
    static let iCloudContainerIdentifier = "iCloud.com.sabri68.fittrack"

    /// `true` only when the app was built with the `FITTRACK_ICLOUD` flag and the iCloud entitlement.
    static var isICloudSyncCompiledIn: Bool {
        #if FITTRACK_ICLOUD
        return true
        #else
        return false
        #endif
    }

    /// UI tests launch the app with this argument to use a fresh in-memory store.
    static var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }

    /// UI tests that check persistence across launches use an on-disk test store.
    static var isUITestingOnDisk: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestingDisk") }

    static var isAnyUITest: Bool { isUITesting || isUITestingOnDisk }

    private static var uiTestStoreURL: URL {
        URL.temporaryDirectory.appending(path: "FitTrackUITest.store")
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else if isUITestingOnDisk {
            if ProcessInfo.processInfo.arguments.contains("-resetStore") {
                let dir = uiTestStoreURL.deletingLastPathComponent()
                let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
                for file in files where file.lastPathComponent.hasPrefix("FitTrackUITest.store") {
                    try? FileManager.default.removeItem(at: file)
                }
            }
            configuration = ModelConfiguration(schema: schema, url: uiTestStoreURL, cloudKitDatabase: .none)
        } else if isICloudSyncCompiledIn {
            configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .private(iCloudContainerIdentifier))
        } else {
            configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
