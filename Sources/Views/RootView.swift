import SwiftUI

enum TimezyTheme {
    static let background = Color(red: 0.055, green: 0.075, blue: 0.065)
    static let surface = Color(red: 0.10, green: 0.135, blue: 0.12)
    static let mint = Color(red: 0.71, green: 0.90, blue: 0.80)
}

struct TimezyButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(TimezyTheme.background)
            .background(TimezyTheme.mint, in: RoundedRectangle(cornerRadius: 18))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 1), value: configuration.isPressed)
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var tab = 0
    var body: some View {
        Group {
            if store.isSignedIn || store.guestMode {
                TabView(selection: $tab) {
                    AgendaView { tab = 1 }.tabItem { Label("Lịch", systemImage: "calendar") }.tag(0)
                    QuickAddView().tabItem { Label("Thêm nhanh", systemImage: "plus.circle") }.tag(1)
                    SettingsView().tabItem { Label("Cài đặt", systemImage: "slider.horizontal.3") }.tag(2)
                }
            } else { WelcomeView() }
        }
        .alert("Timezy", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Đã hiểu", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Label("Timezy", systemImage: "clock").font(.title2.weight(.medium)).padding(.top, 30)
                Spacer(minLength: 36)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 78, weight: .ultraLight)).foregroundStyle(TimezyTheme.mint)
                    .accessibilityHidden(true)
                Text("Dành thời gian\ncho điều quan trọng.")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                Text("Nói một câu. Lưu một cuộc hẹn.\nTimezy giúp bạn nhớ đúng lúc.")
                    .font(.title3).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 18) {
                    Label("Lịch trình, gọn trong một nơi", systemImage: "calendar")
                    Label("Thêm lịch bằng tiếng Việt", systemImage: "waveform")
                    Label("Đồng bộ bằng tài khoản Google", systemImage: "arrow.triangle.2.circlepath")
                }.font(.body).padding(.vertical, 12)
                Button { Task { await store.signIn() } } label: {
                    HStack { if store.signingIn { ProgressView() }; Text("Tiếp tục với Google") }
                }.buttonStyle(TimezyButtonStyle()).disabled(store.signingIn)
                Button("Dùng lịch trên iPhone trước") { store.guestMode = true; store.refreshReminders() }
                    .frame(maxWidth: .infinity, minHeight: 44)
                Text("Lịch trên máy và lịch Google đăng nhập được lưu riêng. API key AI chỉ lưu trong Keychain của thiết bị.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: 560)
        }.frame(maxWidth: .infinity).background(TimezyTheme.background)
    }
}
