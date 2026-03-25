import Foundation
import Network
import UserNotifications

@MainActor
final class ModelDownloadManager: NSObject, ObservableObject {
    static let shared = ModelDownloadManager()

    @Published var isDownloading = false
    @Published var progress: Double = 0.0
    @Published var isModelAvailable = false
    @Published var error: String?
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var downloadPhase: DownloadPhase = .model
    @Published var speedBytesPerSec: Double = 0
    @Published var storageWarning: String?
    @Published var showCellularAlert = false

    fileprivate var resumeData: Data?

    enum DownloadPhase: String {
        case model = "Modell"
        case mmproj = "Vision-Projektor"
    }

    private var downloadTask: URLSessionDownloadTask?
    private var bgSession: URLSession?
    private var currentDestination: URL?
    private var currentCompletion: (@Sendable (Bool) -> Void)?
    private var downloadStartTime: Date?
    private var lastSpeedUpdate: Date?
    private var lastSpeedBytes: Int64 = 0
    private var phase1Bytes: Int64 = 0
    private var lastNotifiedPercent: Int = 0

    /// Background session completion handler (set by AppDelegate)
    static var backgroundCompletionHandler: (() -> Void)?

    private static let bgSessionID = "com.philippschmid.Kalorientracker.model-download"

    override init() {
        super.init()
        isModelAvailable = bothFilesExist()
        requestNotificationPermission()
        reconnectBackgroundSession()
    }

    // MARK: - Paths

    private var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    var modelPath: URL { documentsDir.appendingPathComponent(Constants.localModelName) }
    var mmprojPath: URL { documentsDir.appendingPathComponent(Constants.localMmprojName) }
    var resolvedModelPath: URL { modelPath }
    var resolvedMmprojPath: URL { mmprojPath }

    // MARK: - File checks

    func bothFilesExist() -> Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
            && FileManager.default.fileExists(atPath: mmprojPath.path)
    }

    // MARK: - Storage check

    private var availableStorage: Int64 {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let capacity = values.volumeAvailableCapacityForImportantUsage else { return 0 }
        return capacity
    }

    // MARK: - Network check

    var isOnCellular: Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let name = String(cString: ptr.pointee.ifa_name)
            if name == "pdp_ip0" || name == "pdp_ip1" { return true }
        }
        return false
    }

    // MARK: - Download

    func startDownload(allowCellular: Bool = false) {
        guard !isDownloading else { return }

        // Cellular check
        if !allowCellular && isOnCellular {
            showCellularAlert = true
            return
        }

        // Storage check
        let needed = Constants.localModelSize + 700_000_000
        let available = availableStorage
        storageWarning = nil

        if available < needed + 500_000_000 {
            let availGB = String(format: "%.1f", Double(available) / 1_000_000_000)
            let needGB = String(format: "%.1f", Double(needed) / 1_000_000_000)
            error = "Nicht genug Speicherplatz\n(\(availGB) GB frei, \(needGB) GB benötigt)"
            return
        }

        if available < needed + 5_000_000_000 {
            let remainGB = String(format: "%.1f", Double(available - needed) / 1_000_000_000)
            storageWarning = "Nach dem Download nur noch ~\(remainGB) GB frei"
        }

        isDownloading = true
        progress = 0
        error = nil
        downloadPhase = .model
        downloadedBytes = 0
        totalBytes = Constants.localModelSize + 700_000_000
        speedBytesPerSec = 0
        phase1Bytes = 0
        lastNotifiedPercent = 0

        let mmprojDest = mmprojPath
        downloadFile(url: Constants.localModelURL, destination: modelPath) { [weak self] success in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !success {
                    self.isDownloading = false
                    return
                }
                self.phase1Bytes = self.downloadedBytes
                self.downloadPhase = .mmproj
                self.speedBytesPerSec = 0

                self.downloadFile(url: Constants.localMmprojURL, destination: mmprojDest) { [weak self] success in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.isDownloading = false
                        if success {
                            self.isModelAvailable = true
                            self.progress = 1.0
                            self.sendNotification(title: "Download abgeschlossen", body: "Das On-Device Modell ist bereit!")
                        }
                    }
                }
            }
        }
    }

    private func downloadFile(url urlString: String, destination: URL, completion: @escaping @Sendable (Bool) -> Void) {
        guard let url = URL(string: urlString) else {
            error = "Ungültige Download-URL"
            isDownloading = false
            completion(false)
            return
        }

        currentDestination = destination
        currentCompletion = completion
        downloadStartTime = Date()
        lastSpeedUpdate = Date()
        lastSpeedBytes = phase1Bytes

        // Background session — continues even when app is in background
        let config = URLSessionConfiguration.background(withIdentifier: Self.bgSessionID + ".\(downloadPhase.rawValue)")
        config.timeoutIntervalForResource = 7200 // 2 hours
        config.isDiscretionary = false // don't delay
        config.sessionSendsLaunchEvents = true // wake app on completion
        bgSession = URLSession(configuration: config, delegate: DownloadDelegate(manager: self), delegateQueue: .main)

        let task: URLSessionDownloadTask
        if let resumeData {
            task = bgSession!.downloadTask(withResumeData: resumeData)
            self.resumeData = nil
        } else {
            task = bgSession!.downloadTask(with: url)
        }
        task.resume()
        downloadTask = task
    }

    /// Reconnect to existing background session (after app relaunch)
    private func reconnectBackgroundSession() {
        let configs = [
            Self.bgSessionID + ".Modell",
            Self.bgSessionID + ".Vision-Projektor"
        ]
        for id in configs {
            let config = URLSessionConfiguration.background(withIdentifier: id)
            let _ = URLSession(configuration: config, delegate: DownloadDelegate(manager: self), delegateQueue: .main)
        }
    }

    func cancelDownload() {
        downloadTask?.cancel(byProducingResumeData: { [weak self] data in
            Task { @MainActor in
                self?.resumeData = data
            }
        })
        bgSession?.finishTasksAndInvalidate()
        isDownloading = false
        progress = 0
        downloadedBytes = 0
        speedBytesPerSec = 0
    }

    func deleteModel() {
        try? FileManager.default.removeItem(at: modelPath)
        try? FileManager.default.removeItem(at: mmprojPath)
        isModelAvailable = false
    }

    // MARK: - Delegate callbacks

    fileprivate func handleProgress(bytesWritten: Int64, totalWritten: Int64, totalExpected: Int64) {
        let combinedDownloaded = phase1Bytes + totalWritten
        downloadedBytes = combinedDownloaded

        if totalExpected > 0 && downloadPhase == .model {
            totalBytes = totalExpected + 700_000_000
        } else if totalExpected > 0 && downloadPhase == .mmproj {
            totalBytes = phase1Bytes + totalExpected
        }

        if totalBytes > 0 {
            progress = Double(combinedDownloaded) / Double(totalBytes)
        }

        // Speed every 2 seconds
        let now = Date()
        if let lastUpdate = lastSpeedUpdate, now.timeIntervalSince(lastUpdate) >= 2.0 {
            let byteDiff = combinedDownloaded - lastSpeedBytes
            let timeDiff = now.timeIntervalSince(lastUpdate)
            if timeDiff > 0 { speedBytesPerSec = Double(byteDiff) / timeDiff }
            lastSpeedUpdate = now
            lastSpeedBytes = combinedDownloaded
        }

        // Notify at 25%, 50%, 75%
        let pct = Int(progress * 100)
        if pct >= lastNotifiedPercent + 25 {
            lastNotifiedPercent = (pct / 25) * 25
            sendNotification(title: "Model-Download", body: "\(lastNotifiedPercent)% heruntergeladen...")
        }
    }

    fileprivate func handleCompletion(tempURL: URL?, error: Error?) {
        if let error {
            self.error = error.localizedDescription
            self.isDownloading = false
            currentCompletion?(false)
            return
        }

        guard let tempURL, let destination = currentDestination else {
            self.error = "Download fehlgeschlagen"
            self.isDownloading = false
            currentCompletion?(false)
            return
        }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
            currentCompletion?(true)
        } catch {
            self.error = error.localizedDescription
            self.isDownloading = false
            currentCompletion?(false)
        }

        // Call background completion handler
        Self.backgroundCompletionHandler?()
        Self.backgroundCompletionHandler = nil
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Formatted strings

    var formattedProgress: String {
        let dlMB = Double(downloadedBytes) / 1_000_000
        let totalMB = Double(totalBytes) / 1_000_000
        let speedMB = speedBytesPerSec / 1_000_000
        let step = downloadPhase == .model ? "1/2" : "2/2"

        var text: String
        if totalMB > 0 {
            let pct = Int(progress * 100)
            text = String(format: "(%@) %.0f / %.0f MB (%d%%)", step, dlMB, totalMB, pct)
        } else {
            text = String(format: "(%@) %.0f MB", step, dlMB)
        }

        if speedMB > 0.01 {
            text += String(format: " · %.1f MB/s", speedMB)
        }

        return text
    }

    var formattedETA: String? {
        guard speedBytesPerSec > 100, totalBytes > 0 else { return nil }
        let remaining = Double(totalBytes - downloadedBytes)
        let seconds = remaining / speedBytesPerSec
        if seconds < 60 {
            return "~\(Int(seconds)) Sek. verbleibend"
        } else if seconds < 3600 {
            return "~\(Int(seconds / 60)) Min. verbleibend"
        } else {
            let h = Int(seconds / 3600)
            let m = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "~\(h) Std. \(m) Min. verbleibend"
        }
    }
}

// MARK: - URLSession Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private weak var manager: ModelDownloadManager?

    init(manager: ModelDownloadManager) {
        self.manager = manager
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            self.manager?.handleProgress(bytesWritten: bytesWritten, totalWritten: totalBytesWritten, totalExpected: totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let httpResponse = downloadTask.response as? HTTPURLResponse, httpResponse.statusCode != 200 && httpResponse.statusCode != 206 {
            Task { @MainActor in
                self.manager?.handleCompletion(tempURL: nil, error: NSError(
                    domain: "ModelDownload", code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Server-Fehler \(httpResponse.statusCode)"]))
            }
            return
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: location.path)[.size] as? Int64) ?? 0
        if fileSize < 100_000_000 {
            Task { @MainActor in
                self.manager?.handleCompletion(tempURL: nil, error: NSError(
                    domain: "ModelDownload", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Datei zu klein (\(fileSize / 1_000_000) MB)"]))
            }
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".gguf")
        try? FileManager.default.copyItem(at: location, to: tempFile)

        Task { @MainActor in
            self.manager?.handleCompletion(tempURL: tempFile, error: nil)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let nsError = error as NSError
        if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            Task { @MainActor in self.manager?.resumeData = resumeData }
        }
        if nsError.code == NSURLErrorCancelled { return }
        Task { @MainActor in self.manager?.handleCompletion(tempURL: nil, error: error) }
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        // Background session completed
        Task { @MainActor in
            ModelDownloadManager.backgroundCompletionHandler?()
            ModelDownloadManager.backgroundCompletionHandler = nil
        }
    }
}
