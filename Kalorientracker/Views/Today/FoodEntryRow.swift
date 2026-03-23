import SwiftUI

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let emoji = entry.emoji, !emoji.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Constants.Colors.surface)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(emoji)
                            .font(.system(size: 28))
                    )
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Constants.Colors.surface)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .foregroundStyle(Constants.Colors.textSecondary)
                    )
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(entry.name)
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Constants.Colors.warning)
                    }
                }

                HStack(spacing: 8) {
                    Text(entry.timestamp.shortTime)
                        .font(.caption)
                        .foregroundStyle(Constants.Colors.textSecondary)

                    if entry.source == .onDevice {
                        Label("Lokal", systemImage: "iphone")
                            .font(.caption2)
                            .foregroundStyle(Constants.Colors.gradientStart)
                    }
                }
            }

            Spacer()

            // Calories
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.calories)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(Constants.Colors.textSecondary)
            }
        }
        .padding(14)
        .background(Constants.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Constants.Colors.glassBorder, lineWidth: 0.5)
        )
    }
}

struct MacroPill: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(value.cleanString)g \(label)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}
