import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var user: User?
    @Published var guestMode = false
    @Published var error: String?
    @Published var syncStatus = "Chỉ lưu trên iPhone"
    @Published var reminderStatus = "Chưa kiểm tra thông báo"
    @Published var signingIn = false
    private let notifications = NotificationService()
    private var authListener: AuthStateDidChangeListenerHandle?
    private var eventListener: ListenerRegistration?
    private var reminderTask: Task<Void, Never>?
    private var activeUID: String?
    private var guestReadFailed = false
    var firebaseConfigured: Bool { FirebaseApp.app() != nil }
    var isSignedIn: Bool { user != nil }

    init() {
        loadGuest()
        if firebaseConfigured {
            authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                Task { @MainActor in self?.setUser(user) }
            }
        }
    }

    private var guestURL: URL {
        URL.documentsDirectory.appendingPathComponent("timezy-local-events.json")
    }

    private func loadGuest() {
        guestReadFailed = false
        guard FileManager.default.fileExists(atPath: guestURL.path) else { events = []; return }
        do {
            let values = try JSONDecoder().decode([CalendarEvent].self, from: Data(contentsOf: guestURL))
            for value in values { try value.validate() }
            events = values
        }
        catch { guestReadFailed = true; self.error = "Không đọc được lịch trên máy. Dữ liệu gốc được giữ nguyên; chưa thể ghi thay đổi."; events = [] }
    }

    private func setUser(_ user: User?) {
        guard activeUID != user?.uid || self.user == nil else { self.user = user; return }
        eventListener?.remove()
        eventListener = nil
        activeUID = user?.uid
        self.user = user
        events = []
        guard let user else {
            loadGuest()
            syncStatus = "Chỉ lưu trên iPhone"
            refreshReminders()
            return
        }
        guestMode = false
        syncStatus = "Đang tải lịch tài khoản…"
        refreshReminders()
        let uid = user.uid
        eventListener = Firestore.firestore().collection("users").document(uid).collection("events")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, failure in
                Task { @MainActor in
                    guard let self, self.activeUID == uid else { return }
                    if let failure { self.error = "Đồng bộ thất bại: \(failure.localizedDescription)"; self.syncStatus = "Chưa đồng bộ"; return }
                    guard let snapshot else { return }
                    do {
                        let values = try snapshot.documents.map { document -> CalendarEvent in
                            guard let payload = document.data()["payload"] as? String else {
                                throw TimezyError.message("Lịch trên máy chủ không đúng định dạng.")
                            }
                            let event = try JSONDecoder().decode(CalendarEvent.self, from: Data(payload.utf8))
                            try event.validate()
                            guard event.id == document.documentID else { throw TimezyError.message("Mã lịch không khớp.") }
                            return event
                        }
                        self.events = values.sorted { $0.start < $1.start }
                        self.syncStatus = snapshot.metadata.hasPendingWrites ? "Đang chờ đồng bộ…" :
                            (snapshot.metadata.isFromCache ? "Lịch đã lưu đệm · chờ mạng" : "Đã đồng bộ với Firebase")
                        self.refreshReminders()
                    } catch { self.error = error.localizedDescription }
                }
            }
    }

    func signIn() async {
        guard !signingIn else { return }
        guard firebaseConfigured, let clientID = FirebaseApp.app()?.options.clientID else {
            error = "Chưa cấu hình Firebase. Làm theo docs/SETUP.vi.md và thêm GoogleService-Info.plist rồi build lại."
            return
        }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              var presenter = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return }
        while let presented = presenter.presentedViewController { presenter = presented }
        signingIn = true
        defer { signingIn = false }
        do {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else { throw TimezyError.message("Google không trả về mã đăng nhập.") }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            _ = try await Auth.auth().signIn(with: credential)
        } catch { self.error = "Đăng nhập chưa hoàn tất: \(error.localizedDescription)" }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            guestMode = false
            setUser(nil)
        } catch { self.error = error.localizedDescription }
    }

    func save(_ values: [CalendarEvent]) throws {
        guard !values.isEmpty, values.count <= 20 else { throw TimezyError.message("Mỗi lần lưu tối đa 20 sự kiện.") }
        for event in values { try event.validate() }
        if let uid = user?.uid {
            let database = Firestore.firestore()
            let batch = database.batch()
            for event in values {
                let reference = database.collection("users").document(uid).collection("events").document(event.id)
                let payload = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
                batch.setData(["payload": payload, "updatedAt": FieldValue.serverTimestamp()], forDocument: reference)
            }
            batch.commit { [weak self] failure in
                guard let failure else { return }
                Task { @MainActor in
                    guard self?.activeUID == uid else { return }
                    self?.error = "Máy chủ chưa chấp nhận thay đổi: \(failure.localizedDescription)"
                }
            }
        } else {
            guard !guestReadFailed else { throw TimezyError.message("Tệp lịch đang lỗi. Hãy sao lưu và khôi phục tệp trước khi ghi thêm.") }
            var updated = events.filter { event in !values.contains(where: { $0.id == event.id }) }
            updated.append(contentsOf: values)
            try JSONEncoder().encode(updated).write(to: guestURL, options: [.atomic, .completeFileProtection])
            events = updated.sorted { $0.start < $1.start }
            refreshReminders()
        }
        Task { await enableNotifications() }
    }

    func delete(_ event: CalendarEvent) throws {
        if let uid = user?.uid {
            Firestore.firestore().collection("users").document(uid).collection("events").document(event.id).delete { [weak self] failure in
                if let failure { Task { @MainActor in
                    guard self?.activeUID == uid else { return }
                    self?.error = failure.localizedDescription
                } }
            }
        } else {
            guard !guestReadFailed else { throw TimezyError.message("Không thể sửa tệp lịch đang lỗi.") }
            let updated = events.filter { $0.id != event.id }
            try JSONEncoder().encode(updated).write(to: guestURL, options: [.atomic, .completeFileProtection])
            events = updated
            refreshReminders()
        }
    }

    func enableNotifications() async {
        do {
            let granted = try await notifications.requestPermission()
            if granted {
                refreshReminders()
            } else {
                reminderStatus = "Thông báo bị tắt. Bật lại trong Cài đặt iPhone."
            }
        } catch { self.error = error.localizedDescription }
    }

    func refreshReminders() {
        // Chain replacement operations to avoid old async add calls resurrecting deleted reminders.
        let previous = reminderTask
        let snapshot = events
        reminderTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            self.reminderStatus = await self.notifications.replace(events: snapshot)
        }
    }
}
