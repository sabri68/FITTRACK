import UIKit
import Vision

/// On-device meal photo recognition using Apple's Vision image classifier (no network, no API key).
/// It identifies the kind of food in the picture; portions are confirmed by the user.
enum FoodPhotoRecognizer {
    enum RecognitionError: LocalizedError {
        case invalidImage
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "Image illisible."
            case .failed(let msg): return "L'analyse de la photo a échoué : \(msg)"
            }
        }
    }

    struct Result {
        var candidates: [FoodLabelMap.Candidate]
        var looksLikeFood: Bool
    }

    static func recognize(_ image: UIImage) async throws -> Result {
        guard let cgImage = image.normalizedCGImage() else { throw RecognitionError.invalidImage }
        return try await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                throw RecognitionError.failed(error.localizedDescription)
            }
            let observations = (request.results ?? []).map { (identifier: $0.identifier, confidence: $0.confidence) }
            return Result(candidates: FoodLabelMap.candidates(from: observations),
                          looksLikeFood: FoodLabelMap.looksLikeFood(observations))
        }.value
    }
}

extension UIImage {
    /// Returns an upright, reasonably sized CGImage (classification works best around 1000 px).
    func normalizedCGImage(maxDimension: CGFloat = 1024) -> CGImage? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.cgImage
    }
}
