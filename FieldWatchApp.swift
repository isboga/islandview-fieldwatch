import SwiftUI
import CoreLocation

@main
struct FieldWatchApp: App {
    @StateObject private var tracker = FieldTracker()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(tracker) }
    }
}
