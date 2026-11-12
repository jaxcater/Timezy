import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct TimezyApp: App {
    @StateObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        }
        _store = StateObject(wrappedValue: AppStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(TimezyTheme.mint)
                .environment(\.locale, Locale(identifier: "vi_VN"))
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refreshReminders() }
                }
        }
    }
}
