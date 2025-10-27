import UIKit
import Vision

enum OCRError: LocalizedError {
    case noImage
    case noTextFound
    case visionError(Error)

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "Failed to process image"
        case .noTextFound:
            return "No text found in image"
        case .visionError(let error):
            return "OCR failed: \(error.localizedDescription)"
        }
    }
}

class OCRService {
    static let shared = OCRService()

    private init() {}

    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.noImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.visionError(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let text = recognizedStrings.joined(separator: " ")

                if text.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.visionError(error))
            }
        }
    }
}
