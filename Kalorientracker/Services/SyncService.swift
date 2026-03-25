import Foundation
import SwiftData

@MainActor
final class SyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncError: String?

    private let supabaseURL = Constants.supabaseURL
    private let anonKey = Constants.supabaseAnonKey

    // MARK: - Upload a single entry

    func uploadEntry(_ entry: FoodEntry, accessToken: String) async {
        let url = URL(string: "\(supabaseURL)/rest/v1/food_entries")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        // Get user_id from JWT
        guard let userId = extractUserId(from: accessToken) else { return }

        let body: [String: Any?] = [
            "id": entry.id.uuidString,
            "user_id": userId,
            "entry_timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
            "name": entry.name,
            "calories": entry.calories,
            "protein": entry.protein,
            "carbs": entry.carbs,
            "fat": entry.fat,
            "confidence": entry.confidence,
            "portion_description": entry.portionDescription,
            "suggestion": entry.suggestion,
            "emoji": entry.emoji,
            "analysis_source": entry.analysisSource,
            "meal_category": entry.mealCategoryRaw,
            "is_favorite": entry.isFavorite,
            "image_data": entry.imageData?.base64EncodedString(),
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
                print("Sync upload error: \(http.statusCode)")
            } else {
                entry.isSynced = true
            }
        } catch {
            print("Sync upload failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Upload profile

    func uploadProfile(_ profile: UserProfile, accessToken: String) async {
        let url = URL(string: "\(supabaseURL)/rest/v1/user_profiles")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        guard let userId = extractUserId(from: accessToken) else { return }

        let body: [String: Any] = [
            "id": profile.id.uuidString,
            "user_id": userId,
            "age": profile.age,
            "weight_kg": profile.weightKg,
            "height_cm": profile.heightCm,
            "is_male": profile.isMale,
            "activity_level": profile.activityLevel,
            "weekly_training_hours": profile.weeklyTrainingHours,
            "target_calories": profile.targetCalories,
            "use_computed_target": profile.useComputedTarget,
            "goal": profile.goalRaw,
            "ai_mode": profile.aiModeRaw,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
                print("Profile sync error: \(http.statusCode)")
            }
        } catch {
            print("Profile sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Pull entries from server

    func pullEntries(accessToken: String, modelContext: ModelContext) async {
        guard let userId = extractUserId(from: accessToken) else { return }
        isSyncing = true
        lastSyncError = nil

        let urlStr = "\(supabaseURL)/rest/v1/food_entries?user_id=eq.\(userId)&order=entry_timestamp.desc&limit=500"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                isSyncing = false
                return
            }

            let entries = try JSONDecoder().decode([ServerFoodEntry].self, from: data)

            // Get existing local IDs
            let descriptor = FetchDescriptor<FoodEntry>()
            let localEntries = (try? modelContext.fetch(descriptor)) ?? []
            let localIds = Set(localEntries.map { $0.id })

            var newCount = 0
            for serverEntry in entries {
                guard let entryId = UUID(uuidString: serverEntry.id) else { continue }
                if localIds.contains(entryId) { continue } // already exists locally

                let entry = FoodEntry(
                    name: serverEntry.name,
                    calories: serverEntry.calories ?? 0,
                    protein: serverEntry.protein ?? 0,
                    carbs: serverEntry.carbs ?? 0,
                    fat: serverEntry.fat ?? 0,
                    confidence: serverEntry.confidence ?? 0.5,
                    imageData: serverEntry.image_data.flatMap { Data(base64Encoded: $0) },
                    portionDescription: serverEntry.portion_description ?? "",
                    suggestion: serverEntry.suggestion,
                    emoji: serverEntry.emoji,
                    analysisSource: AnalysisSource(rawValue: serverEntry.analysis_source ?? "cloud") ?? .cloud,
                    mealCategory: MealCategory(rawValue: serverEntry.meal_category ?? "snack")
                )
                entry.id = entryId
                entry.timestamp = ISO8601DateFormatter().date(from: serverEntry.entry_timestamp) ?? Date()
                entry.isFavorite = serverEntry.is_favorite ?? false
                entry.isSynced = true
                modelContext.insert(entry)
                newCount += 1
            }

            if newCount > 0 {
                print("Synced \(newCount) entries from server")
            }
        } catch {
            lastSyncError = error.localizedDescription
            print("Pull entries failed: \(error)")
        }

        isSyncing = false
    }

    // MARK: - Push all unsynced entries

    func pushUnsyncedEntries(entries: [FoodEntry], accessToken: String) async {
        let unsynced = entries.filter { !$0.isSynced }
        for entry in unsynced {
            await uploadEntry(entry, accessToken: accessToken)
        }
    }

    // MARK: - Helpers

    private func extractUserId(from jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
        // Pad base64
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        return sub
    }
}

// MARK: - Server response model

private struct ServerFoodEntry: Codable {
    let id: String
    let entry_timestamp: String
    let name: String
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let confidence: Double?
    let portion_description: String?
    let suggestion: String?
    let emoji: String?
    let analysis_source: String?
    let meal_category: String?
    let is_favorite: Bool?
    let image_data: String?
}
