import Flutter
import SwiftyTesseract
import UIKit

public class SwiftFlutterTesseractOcrPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_tesseract_ocr",
            binaryMessenger: registrar.messenger()
        )
        let instance = SwiftFlutterTesseractOcrPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        initializeTessData()

        guard call.method == "extractText" || call.method == "extractHocr" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard let args = call.arguments as? [String: Any] else {
            result("iOS could not recognize flutter arguments in method: (sendParams)")
            return
        }

        let language = args["language"] as? String

        var tesseract = SwiftyTesseract(language: .english)

        if let lang = language, !lang.isEmpty {
            tesseract = SwiftyTesseract(language: .custom(lang))
        }

        if let imageBytes = args["imageBytes"] as? FlutterStandardTypedData {
            guard let image = UIImage(data: imageBytes.data) else {
                result("Failed to decode image from imageBytes")
                return
            }

            performOcr(on: image, method: call.method, swiftyTesseract: tesseract, result: result)

        } else if let imagePath = args["imagePath"] as? String {
            guard let image = UIImage(contentsOfFile: imagePath) else {
                result("Failed to load image from imagePath")
                return
            }

            performOcr(on: image, method: call.method, swiftyTesseract: tesseract, result: result)

        } else {
            result("You must provide either imagePath or imageBytes")
        }
    }

    func performOcr(
        on image: UIImage,
        method: String,
        swiftyTesseract: SwiftyTesseract,
        result: @escaping FlutterResult
    ) {
        swiftyTesseract.performOCR(on: image) { recognizedString in
            guard let recognizedString = recognizedString else {
                result("OCR failed to extract text")
                return
            }

            if method == "extractHocr" {
                result("hOCR output is not supported on iOS with current SwiftyTesseract version")
            } else {
                result(recognizedString)
            }

            result(recognizedString)
        }
    }

    func initializeTessData() {
        let fileManager = FileManager.default

        guard
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            print("Could not resolve documents directory")
            return
        }

        let destURL = documentsURL.appendingPathComponent("tessdata")
        let sourceURL = Bundle.main.bundleURL.appendingPathComponent("tessdata")

        if fileManager.fileExists(atPath: destURL.path) {
            return
        }

        do {
            try fileManager.createSymbolicLink(at: destURL, withDestinationURL: sourceURL)
        } catch {
            print("Failed to create tessdata symlink: \(error)")
        }
    }
}
