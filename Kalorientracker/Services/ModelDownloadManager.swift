import Foundation

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

    fileprivate var resumeData: Data?

    enum DownloadPhase: String {
        case model = "Modell"
        case mmproj = "Vision-Projektor"
    }

    private var downloadTask: URLSessionDownloadTask?
    private var session: URLSession?
    private var currentDestination: URL?
    private var currentCompletion: (@Sendable (Bool) -> Void)?
    private var downloadStartTime: Date?
    private var lastSpeedUpdate: Date?
    private var lastSpeedBytes: Int64 = 0

    override init() {
        super.init()
        isModelAvailable = bothFilesExist()
    }

    // MARK: - Paths

    private var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    var modelPath: URL {
        documentsDir.appendingPathComponent(Constants.localModelName)
    }

    var mmprojPath: URL {
        documentsDir.appendingPathComponent(Constants.localMmprojName)
    }

    var resolvedModelPath: URL { modelPath }
    var resolvedMmprojPath: URL { mmprojPath }

    // MARK: - File checks

    func bothFilesExist() -> Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
            && FileManager.default.fileExists(atPath: mmprojPath.path)
    }

    // MARK: - Download

    /// Check available disk space in bytes
    private var availableStorage: Int64 {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let capacity = values.volumeAvailableCapacityForImportantUsage else { return 0 }
        return capacity
    }

    func startDownload() {
        guard !isDownloading else { return }

        // Check disk space
        let needed = Constants.localModelSize + 700_000_000 // model + mmproj
        let available = availableStorage
        storageWarning = nil

        if available < needed + 500_000_000 { // less than 500MB buffer
            let availGB = String(format: "%.1f", Double(available) / 1_000_000_000)
            let needGB = String(format: "%.1f", Double(needed) / 1_000_000_000)
            error = "Nicht genug Speicherplatz\n(\(availGB) GB frei, \(needGB) GB benötigt)"
            return
        }

        if available < needed + 5_000_000_000 { // less than 5GB remaining after download
            let remainGB = String(format: "%.1f", Double(available - needed) / 1_000_000_000)
            storageWarning = "Achtung: Nach dem Download nur noch ~\(remainGB) GB frei"
        }

        isDownloading = true
        progress = 0
        error = nil
        downloadPhase = .model
        downloadedBytes = 0
        totalBytes = Constants.localModelSize
        speedBytesPerSec = 0

        let mmprojDest = mmprojPath
        downloadFile(url: Constants.localModelURL, destination: modelPath) { [weak self] success in
            Task { @MainActor [weak self] in
                guard let self, success else { return }
                self.downloadPhase = .mmproj
                self.progress = 0
                self.downloadedBytes = 0
                self.totalBytes = 0
                self.speedBytesPerSec = 0

                self.downloadFile(url: Constants.localMmprojURL, destination: mmprojDest) { [weak self] success in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.isDownloading = false
                        if success {
                            self.isModelAvailable = true
                            self.progress = 1.0
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
        lastSpeedBytes = 0

        // Use delegate-based session for reliable progress
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 3600
        session = URLSession(configuration: config, delegate: DownloadDelegate(manager: self), delegateQueue: .main)

        // Resume if we have resume data from a previous attempt
        let task: URLSessionDownloadTask
        if let resumeData {
            task = session!.downloadTask(withResumeData: resumeData)
            self.resumeData = nil
        } else {
            task = session!.downloadTask(with: url)
        }
        task.resume()
        downloadTask = task
    }

    func cancelDownload() {
        downloadTask?.cancel(byProducingResumeData: { [weak self] data in
            Task { @MainActor in
                self?.resumeData = data
            }
        })
        session?.finishTasksAndInvalidate()
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

    // Called by delegate
    fileprivate func handleProgress(bytesWritten: Int64, totalWritten: Int64, totalExpected: Int64) {
        downloadedBytes = totalWritten
        if totalExpected > 0 {
            totalBytes = totalExpected
            progress = Double(totalWritten) / Double(totalExpected)
        }

        // Calculate speed every 2 seconds
        let now = Date()
        if let lastUpdate = lastSpeedUpdate, now.timeIntervalSince(lastUpdate) >= 2.0 {
            let byteDiff = totalWritten - lastSpeedBytes
            let timeDiff = now.timeIntervalSince(lastUpdate)
            if timeDiff > 0 {
                speedBytesPerSec = Double(byteDiff) / timeDiff
            }
            lastSpeedUpdate = now
            lastSpeedBytes = totalWritten
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
    }

    var formattedProgress: String {
        let dlMB = Double(downloadedBytes) / 1_000_000
        let totalMB = Double(totalBytes) / 1_000_000
        let speedMB = speedBytesPerSec / 1_000_000
        let phase = downloadPhase.rawValue

        var text: String
        if totalMB > 0 {
            let pct = Int(progress * 100)
            text = String(format: "%@ — %.0f / %.0f MB (%d%%)", phase, dlMB, totalMB, pct)
        } else {
            text = String(format: "%@ — %.0f MB", phase, dlMB)
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

// MARK: - URLSession Delegate (for reliable download progress)

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
        // Copy to temp because the file gets deleted after this callback
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".gguf")
        try? FileManager.default.copyItem(at: location, to: tempFile)

        Task { @MainActor in
            self.manager?.handleCompletion(tempURL: tempFile, error: nil)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        // Save resume data for network errors
        let nsError = error as NSError
        if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            Task { @MainActor in
                self.manager?.resumeData = resumeData
            }
        }
        if nsError.code == NSURLErrorCancelled { return }
        Task { @MainActor in
            self.manager?.handleCompletion(tempURL: nil, error: error)
        }
    }
}
