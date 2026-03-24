import Foundation

@MainActor
final class ModelDownloadManager: ObservableObject {
    static let shared = ModelDownloadManager()

    @Published var isDownloading = false
    @Published var progress: Double = 0.0
    @Published var isModelAvailable = false
    @Published var error: String?
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var downloadPhase: DownloadPhase = .model

    enum DownloadPhase: String {
        case model = "Modell"
        case mmproj = "Vision-Projektor"
    }

    private var downloadTask: URLSessionDownloadTask?
    private var _progressObservation: NSKeyValueObservation?

    init() {
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

    // MARK: - Dev bypass (uses repo models/ directory in DEBUG)

    #if DEBUG
    private var devModelsDir: URL? {
        // #filePath points to this source file → navigate up to repo root
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceFile
            .deletingLastPathComponent() // Services/
            .deletingLastPathComponent() // Kalorientracker/
            .deletingLastPathComponent() // project root
        let modelsDir = repoRoot.appendingPathComponent("models")
        guard FileManager.default.fileExists(atPath: modelsDir.path) else { return nil }
        return modelsDir
    }

    private var devModelPath: URL? {
        guard let dir = devModelsDir else { return nil }
        let path = dir.appendingPathComponent(Constants.localModelName)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }

    private var devMmprojPath: URL? {
        guard let dir = devModelsDir else { return nil }
        let path = dir.appendingPathComponent(Constants.localMmprojName)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }
    #endif

    /// Resolved model path: dev path in DEBUG, otherwise downloaded path
    var resolvedModelPath: URL {
        #if DEBUG
        if let devPath = devModelPath { return devPath }
        #endif
        return modelPath
    }

    /// Resolved mmproj path: dev path in DEBUG, otherwise downloaded path
    var resolvedMmprojPath: URL {
        #if DEBUG
        if let devPath = devMmprojPath { return devPath }
        #endif
        return mmprojPath
    }

    // MARK: - File checks

    private func modelFileExists() -> Bool {
        FileManager.default.fileExists(atPath: modelPath.path)
    }

    private func mmprojFileExists() -> Bool {
        FileManager.default.fileExists(atPath: mmprojPath.path)
    }

    func bothFilesExist() -> Bool {
        #if DEBUG
        if devModelPath != nil && devMmprojPath != nil { return true }
        #endif
        return modelFileExists() && mmprojFileExists()
    }

    // MARK: - Download

    func startDownload() {
        guard !isDownloading else { return }
        isDownloading = true
        progress = 0
        error = nil
        downloadPhase = .model

        // Download model first, then mmproj
        downloadFile(
            url: Constants.localModelURL,
            destination: modelPath
        ) { [weak self] success in
            guard let self, success else { return }
            self.downloadPhase = .mmproj
            self.progress = 0
            self.downloadedBytes = 0
            self.totalBytes = 0

            self.downloadFile(
                url: Constants.localMmprojURL,
                destination: self.mmprojPath
            ) { [weak self] success in
                guard let self else { return }
                self.isDownloading = false
                if success {
                    self.isModelAvailable = true
                    self.progress = 1.0
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

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
        let task = session.downloadTask(with: url) { [weak self] tempURL, _, downloadError in
            Task { @MainActor in
                guard let self else { return }

                if let downloadError {
                    self.error = downloadError.localizedDescription
                    self.isDownloading = false
                    completion(false)
                    return
                }

                guard let tempURL else {
                    self.error = "Download fehlgeschlagen"
                    self.isDownloading = false
                    completion(false)
                    return
                }

                do {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destination)
                    completion(true)
                } catch {
                    self.error = error.localizedDescription
                    self.isDownloading = false
                    completion(false)
                }
            }
        }

        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progressObj, _ in
            Task { @MainActor in
                self?.progress = progressObj.fractionCompleted
                self?.downloadedBytes = progressObj.completedUnitCount
                self?.totalBytes = progressObj.totalUnitCount
            }
        }

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
        try? FileManager.default.removeItem(at: mmprojPath)
        isModelAvailable = false
    }

    var formattedProgress: String {
        let downloadedMB = Double(downloadedBytes) / 1_000_000
        let totalMB = Double(totalBytes) / 1_000_000
        let phase = downloadPhase.rawValue
        if totalMB > 0 {
            return String(format: "%@ — %.0f / %.0f MB", phase, downloadedMB, totalMB)
        }
        return String(format: "%@ — %.0f MB", phase, downloadedMB)
    }
}
