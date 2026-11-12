import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var configuration = AIConfiguration.load()
    @State private var key = ""
    @State private var status: String?
    @State private var confirmingSignOut = false
    @State private var permissionBusy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Tài khoản & đồng bộ") {
                    if let user = store.user {
                        Label(user.displayName ?? "Tài khoản Google", systemImage: "person.crop.circle")
                        if let email = user.email { Text(email).font(.subheadline).foregroundStyle(.secondary) }
                        Label(store.syncStatus, systemImage: "icloud").font(.subheadline)
                        Button("Đăng xuất", role: .destructive) { confirmingSignOut = true }
                    } else {
                        Label("Đang dùng lịch trên iPhone", systemImage: "iphone")
                        Text("Đăng nhập để dùng lịch đồng bộ. Lịch trên máy được giữ riêng, không tự tải lên tài khoản.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Đăng nhập bằng Google") { Task { await store.signIn() } }.disabled(store.signingIn)
                        if !store.firebaseConfigured {
                            Text("Bản build này chưa cấu hình Firebase. Xem hướng dẫn SETUP.vi.md đi kèm mã nguồn.")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                    }
                }
                Section("Nhắc lịch") {
                    Text(store.reminderStatus).font(.subheadline)
                    Button("Cho phép thông báo") {
                        permissionBusy = true
                        Task { await store.enableNotifications(); permissionBusy = false }
                    }.disabled(permissionBusy)
                    Button("Mở Cài đặt iPhone") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    Text("Timezy đặt tối đa 60 lời nhắc gần nhất, trong vòng 1 năm và làm mới khi mở app hoặc đổi lịch. Mở app định kỳ để bổ sung lời nhắc. Chế độ Tập trung của iOS có thể làm im lặng thông báo.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Picker("Giao thức", selection: $configuration.provider) {
                        ForEach(AIProtocol.allCases) { Text($0.label).tag($0) }
                    }
                    .onChange(of: configuration.provider) { _, provider in
                        configuration.endpoint = provider.endpoint
                        configuration.model = ""
                        key = KeychainStore.read(configuration.keyAccount)
                        status = nil
                    }
                    TextField("Endpoint HTTPS (base URL)", text: $configuration.endpoint)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .onChange(of: configuration.endpoint) { _, _ in
                            key = KeychainStore.read(configuration.keyAccount)
                            status = nil
                        }
                    TextField("Model ID từ nhà cung cấp", text: $configuration.model)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("API key của bạn", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Lưu cấu hình AI") { saveConfiguration() }.fontWeight(.semibold)
                    if let status { Text(status).font(.footnote).foregroundStyle(TimezyTheme.mint) }
                } header: { Text("AI của bạn") } footer: {
                    Text("Hỗ trợ OpenAI Chat Completions, Gemini GenerateContent, Anthropic Messages và endpoint tương thích. OpenRouter, Groq, DeepSeek… dùng giao thức OpenAI nếu endpoint/model hỗ trợ. Dịch vụ dùng giao thức khác cần thêm bộ kết nối. API key không đồng bộ lên Firebase.")
                }
                Section("Quyền riêng tư") {
                    Text("Lịch đăng nhập được lưu trong Firebase của ứng dụng. Giọng nói dùng Apple Speech. Chỉ văn bản bạn xác nhận gửi mới được chuyển tới endpoint AI đã cấu hình.")
                    Text("Xóa nội dung API key rồi bấm Lưu để xóa key của endpoint hiện tại khỏi thiết bị.")
                }.font(.footnote)
                Section { Text("Timezy · thời gian cho điều quan trọng").foregroundStyle(.secondary).font(.footnote) }
            }.scrollContentBackground(.hidden).background(TimezyTheme.background)
                .navigationTitle("Cài đặt")
                .onAppear { configuration = AIConfiguration.load(); key = KeychainStore.read(configuration.keyAccount); store.refreshReminders() }
                .confirmationDialog("Đăng xuất tài khoản?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
                    Button("Đăng xuất", role: .destructive) { store.signOut() }
                } message: { Text("Hãy đợi đồng bộ hoàn tất. Lịch tài khoản sẽ ẩn và lời nhắc tài khoản trên máy này sẽ được gỡ.") }
        }
    }

    private func saveConfiguration() {
        do {
            configuration.endpoint = configuration.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            configuration.model = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: configuration.endpoint), url.scheme == "https", url.host != nil,
                  url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
                throw TimezyError.message("Endpoint phải là URL HTTPS hợp lệ không chứa query hay mật khẩu.")
            }
            try KeychainStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines), account: configuration.keyAccount)
            try configuration.save()
            status = "Đã lưu cấu hình trên thiết bị."
        } catch { status = error.localizedDescription }
    }
}
