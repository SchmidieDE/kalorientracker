import UIKit
import llama

/// On-device food analysis using llama.cpp with Qwen3.5 Vision GGUF models.
///
/// Uses the llama.cpp C API for model loading and text generation.
/// Vision support requires clip/llava functions — if not available in the SPM package,
/// add the source files from llama.cpp/examples/llava/ to the Xcode project.
///
/// Required functions from llava API (may need manual inclusion):
///   - clip_model_load(), clip_free()
///   - llava_image_embed_make_with_bytes(), llava_image_embed_free()
///   - llava_eval_image_embed()
final class LocalInferenceService: @unchecked Sendable {

    enum InferenceError: LocalizedError {
        case modelNotFound
        case modelLoadFailed
        case mmprojNotFound
        case mmprojLoadFailed
        case imageEncodingFailed
        case inferenceFailed(String)
        case jsonParsingFailed

        var errorDescription: String? {
            switch self {
            case .modelNotFound: return "GGUF-Modell nicht gefunden"
            case .modelLoadFailed: return "Modell konnte nicht\ngeladen werden"
            case .mmprojNotFound: return "Vision-Projektor\nnicht gefunden"
            case .mmprojLoadFailed: return "Vision-Projektor konnte\nnicht geladen werden"
            case .imageEncodingFailed: return "Bild konnte nicht\nverarbeitet werden"
            case .inferenceFailed(let msg): return "Inferenz fehlgeschlagen:\n\(msg)"
            case .jsonParsingFailed: return "Antwort konnte nicht\nverarbeitet werden"
            }
        }
    }

    private static let analysisPrompt = """
    Analyze the food in this image. Respond ONLY with a JSON object, no other text:
    {"isFood":true,"name":"food name in German","calories":0,"protein":0.0,"carbs":0.0,"fat":0.0,"confidence":0.0,"portionDescription":"portion size","suggestions":"health tip","emoji":"🍽️"}
    If no food is visible, respond: {"isFood":false,"name":"Kein Essen","calories":0,"protein":0.0,"carbs":0.0,"fat":0.0,"confidence":0.0,"portionDescription":"","suggestions":"","emoji":"❌"}
    """

    /// Analyze a food image using the local GGUF model.
    /// Runs on a background thread to avoid blocking the UI.
    func analyze(image: UIImage, modelPath: URL, mmprojPath: URL) async throws -> NutritionResult {
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw InferenceError.modelNotFound
        }
        guard FileManager.default.fileExists(atPath: mmprojPath.path) else {
            throw InferenceError.mmprojNotFound
        }

        // Resize image for Qwen3.5-VL (448x448 native resolution)
        guard let resizedImage = image.resized(maxDimension: 448),
              let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw InferenceError.imageEncodingFailed
        }

        // Run inference on background thread (llama.cpp C API is synchronous)
        return try await Task.detached(priority: .userInitiated) {
            try self.runInference(
                imageData: imageData,
                modelPath: modelPath.path,
                mmprojPath: mmprojPath.path
            )
        }.value
    }

    // MARK: - Core inference

    private func runInference(imageData: Data, modelPath: String, mmprojPath: String) throws -> NutritionResult {
        llama_backend_init()
        defer { llama_backend_free() }

        // Load main GGUF model with Metal GPU offloading
        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 99
        guard let model = llama_model_load_from_file(modelPath, modelParams) else {
            throw InferenceError.modelLoadFailed
        }
        defer { llama_model_free(model) }

        // Create inference context
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = 4096
        ctxParams.n_batch = 512
        let nThreads = UInt32(min(ProcessInfo.processInfo.activeProcessorCount, 4))
        ctxParams.n_threads = nThreads
        ctxParams.n_threads_batch = nThreads
        guard let ctx = llama_init_from_model(model, ctxParams) else {
            throw InferenceError.inferenceFailed("Context konnte nicht erstellt werden")
        }
        defer { llama_free(ctx) }

        // Load clip model (multimodal projector)
        guard let clipCtx = clip_model_load(mmprojPath, 1) else {
            throw InferenceError.mmprojLoadFailed
        }
        defer { clip_free(clipCtx) }

        // Create image embeddings from JPEG bytes
        let imageEmbed: OpaquePointer? = imageData.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return nil }
            return llava_image_embed_make_with_bytes(
                clipCtx,
                Int32(nThreads),
                ptr.assumingMemoryBound(to: UInt8.self),
                Int32(imageData.count)
            )
        }
        guard let imageEmbed else {
            throw InferenceError.imageEncodingFailed
        }
        defer { llava_image_embed_free(imageEmbed) }

        // Evaluate image embeddings into context
        var pos: Int32 = 0
        llava_eval_image_embed(ctx, imageEmbed, Int32(ctxParams.n_batch), &pos)

        // Tokenize text prompt
        let vocab = llama_model_get_vocab(model)
        let prompt = Self.analysisPrompt
        let tokens = tokenize(vocab: vocab, text: prompt, addSpecial: true)

        // Evaluate prompt tokens
        let batchSize = Int32(tokens.count)
        var batch = llama_batch_init(batchSize, 0, 1)
        defer { llama_batch_free(batch) }

        for (i, token) in tokens.enumerated() {
            batchAdd(&batch, token: token, pos: pos + Int32(i), seqId: 0, logits: i == tokens.count - 1)
        }
        pos += Int32(tokens.count)

        guard llama_decode(ctx, batch) == 0 else {
            throw InferenceError.inferenceFailed("Prompt-Dekodierung fehlgeschlagen")
        }

        // Set up sampler (low temperature for deterministic JSON output)
        let samplerParams = llama_sampler_chain_default_params()
        guard let sampler = llama_sampler_chain_init(samplerParams) else {
            throw InferenceError.inferenceFailed("Sampler-Fehler")
        }
        defer { llama_sampler_free(sampler) }

        llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.1))
        llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))

        // Generate tokens
        let eosToken = llama_vocab_eos(vocab)
        var outputText = ""

        for _ in 0..<512 {
            let newToken = llama_sampler_sample(sampler, ctx, -1)
            if newToken == eosToken { break }

            // Convert token to string piece
            var buf = [CChar](repeating: 0, count: 256)
            let len = llama_token_to_piece(vocab, newToken, &buf, Int32(buf.count), 0, true)
            if len > 0 {
                buf[Int(len)] = 0 // null-terminate
                outputText += String(cString: buf)
            }

            // Decode next token
            batchClear(&batch)
            batchAdd(&batch, token: newToken, pos: pos, seqId: 0, logits: true)
            pos += 1

            if llama_decode(ctx, batch) != 0 { break }
        }

        return try parseNutritionResult(from: outputText)
    }

    // MARK: - Batch helpers (llama_batch_add/clear are not in the Swift bridge)

    private func batchClear(_ batch: inout llama_batch) {
        batch.n_tokens = 0
    }

    private func batchAdd(_ batch: inout llama_batch, token: llama_token, pos: Int32, seqId: Int32, logits: Bool) {
        let idx = Int(batch.n_tokens)
        batch.token[idx] = token
        batch.pos[idx] = pos
        batch.n_seq_id[idx] = 1
        batch.seq_id[idx]![0] = seqId
        batch.logits[idx] = logits ? 1 : 0
        batch.n_tokens += 1
    }

    // MARK: - Tokenization

    private func tokenize(vocab: OpaquePointer, text: String, addSpecial: Bool) -> [llama_token] {
        let maxTokens = Int32(text.utf8.count + 64)
        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))
        let count = llama_tokenize(vocab, text, Int32(text.utf8.count), &tokens, maxTokens, addSpecial, true)
        guard count > 0 else { return [] }
        return Array(tokens.prefix(Int(count)))
    }

    // MARK: - JSON parsing

    private func parseNutritionResult(from text: String) throws -> NutritionResult {
        // Extract JSON object from model output (may include surrounding text)
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}") else {
            throw InferenceError.jsonParsingFailed
        }

        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw InferenceError.jsonParsingFailed
        }

        let result = try JSONDecoder().decode(NutritionResult.self, from: jsonData)
        if result.isFood == false || result.confidence < 0.1 {
            throw InferenceError.inferenceFailed("Kein Essen erkannt")
        }
        return result
    }
}
