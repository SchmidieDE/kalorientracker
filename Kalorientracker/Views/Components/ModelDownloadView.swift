import SwiftUI

struct ModelDownloadView: View {
    @ObservedObject var manager: ModelDownloadManager

    var body: some View {
        VStack(spacing: 16) {
            if manager.isDownloading {
                VStack(spacing: 12) {
                    ProgressView(value: manager.progress)
                        .tint(Constants.Colors.gradientStart)
                        .scaleEffect(y: 2)

                    HStack {
                        Text("Lade Qwen3-VL...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(manager.formattedProgress)
                            .font(.caption)
                            .foregroundStyle(Constants.Colors.textSecondary)
                    }

                    Text("\(Int(manager.progress * 100))%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Constants.Colors.gradientStart)
                }
            }
        }
    }
}
