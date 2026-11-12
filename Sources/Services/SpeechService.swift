import AVFoundation
import Speech
import SwiftUI

@MainActor
final class SpeechService: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var isStarting = false
    @Published var isFinishing = false
    @Published var error: String?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasTap = false
    private var generation = UUID()

    func start() async {
        guard !isStarting, !isRecording, !isFinishing else { return }
        isStarting = true
        error = nil
        let token = UUID()
        generation = token
        defer { if generation == token { isStarting = false } }
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        let microphone = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard generation == token, !Task.isCancelled else { return }
        guard speech == .authorized, microphone else {
            error = "Cho phép Micro và Nhận dạng giọng nói trong Cài đặt iPhone để nhập bằng giọng nói."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            error = "Nhận dạng tiếng Việt hiện không khả dụng. Kiểm tra kết nối mạng hoặc nhập văn bản."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            self.request = request
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw TimezyError.message("Không tìm thấy micro khả dụng.")
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            hasTap = true
            transcript = ""
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, recognitionError in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    if let result { self.transcript = result.bestTranscription.formattedString }
                    if let recognitionError {
                        self.error = "Nhận dạng giọng nói bị gián đoạn: \(recognitionError.localizedDescription)"
                        self.stop()
                    } else if result?.isFinal == true { self.stop() }
                }
            }
            engine.prepare()
            try engine.start()
            isRecording = true
        } catch {
            self.error = error.localizedDescription
            stop()
        }
    }

    func stop() {
        generation = UUID()
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        isRecording = false
        isStarting = false
        isFinishing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func finish() {
        guard isRecording else { stop(); return }
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        isRecording = false
        isFinishing = true
        request?.endAudio()
        let token = generation
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, self.generation == token, self.isFinishing else { return }
            self.stop()
        }
    }
}
