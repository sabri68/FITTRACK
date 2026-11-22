// Prints the identifiers supported by Apple's on-device image classifier (used for meal photo recognition).
import Vision
let request = VNClassifyImageRequest()
if let ids = try? request.supportedIdentifiers() {
    print("VISION_LABEL_COUNT \(ids.count)")
    print(ids.joined(separator: "\n"))
}
