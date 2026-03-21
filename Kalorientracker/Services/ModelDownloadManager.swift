import Foundation

@MainActor
final class ModelDownloadManager: ObservableObject {
    @Published var isDownloading = false
    @Published var progress: Double = 0.0
    @Published var isModelAvailable = false
    @Published var error: String?
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0

    private var downloadTask: URLSessionDownloadTask?

    init() {
        isModelAvailable = modelFileExists()
    }

    var modelPath: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent(Constants.localModelName)
    }

    func modelFileExists() -> Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
    }

    func startDownload() {
        guard !isDownloading else { return }
        guard let url = URL(string: Constants.localModelURL) else { return }

        isDownloading = true
        progress = 0
        error = nil

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
        let task = session.downloadTask(with: url) { [weak self] tempURL, response, downloadError in
            Task { @MainActor in
                guard let self else { return }
                self.isDownloading = false

                if let downloadError {
                    self.error = downloadError.localizedDescription
                    return
                }

                guard let tempURL else {
                    self.error = "Download fehlgeschlagen"
                    return
                }

                do {
                    if self.modelFileExists() {
                        try FileManager.default.removeItem(at: self.modelPath)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: self.modelPath)
                    self.isModelAvailable = true
                    self.progress = 1.0
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }

        // Observe progress
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progressObj, _ in
            Task { @MainActor in
                self?.progress = progressObj.fractionCompleted
                self?.downloadedBytes = progressObj.completedUnitCount
                self?.totalBytes = progressObj.totalUnitCount
            }
        }

        // Store observation to keep it alive
        _progressObservation = observation

        task.resume()
        downloadTask = task
    }

    func cancelDownload() {
        downloadTask?.cancel()
        isDownloading = false
        progress = 0
    }

    func deleteModel() {
        try? FileManager.default.removeItem(at: modelPath)
        isModelAvailable = false
    }

    private var _progressObservation: NSKeyValueObservation?

    var formattedProgress: String {
        let downloadedMB = Double(downloadedBytes) / 1_000_000
        let totalMB = Double(totalBytes) / 1_000_000
        if totalMB > 0 {
            return String(format: "%.0f / %.0f MB", downloadedMB, totalMB)
        }
        return String(format: "%.0f MB", downloadedMB)
    }
}
