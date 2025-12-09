import Flutter
import UIKit
import SwiftyTesseract

public class SwiftFlutterTesseractOcrPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_tesseract_ocr", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterTesseractOcrPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        initializeTessData()

        guard call.method == "extractText" || call.method == "extractHocr" else { return }

        guard let args = call.arguments as? [String: Any] else {
            result("Invalid arguments")
            return
        }

        let language = (args["language"] as? String)
        var swiftyTesseract = SwiftyTesseract(language: .english)

        if let lang = language {
            swiftyTesseract = SwiftyTesseract(language: .custom(lang))
        }

        if let imageBytes = args["imageBytes"] as? FlutterStandardTypedData {
            if let image = UIImage(data: imageBytes.data) {
                performOcr(on: image, method: call.method, swiftyTesseract: swiftyTesseract, result: result)
            } else {
                result("Failed to decode image from imageBytes")
            }
        } else if let imagePath = args["imagePath"] as? String {
            guard let image = UIImage(contentsOfFile: imagePath) else {
                result("Failed to load image from imagePath")
                return
            }
            performOcr(on: image, method: call.method, swiftyTesseract: swiftyTesseract, result: result)
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
        if method == "extractHocr" {
            let config = OcrConfig(output: .hocr)
            swiftyTesseract.performOCR(on: image, config: config) { hocr in
                result(hocr ?? "")
            }
        } else {
            swiftyTesseract.performOCR(on: image) { text in
                result(text ?? "")
            }
        }
    }

    func initializeTessData() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destURL = documentsURL.appendingPathComponent("tessdata")
        let sourceURL = Bundle.main.bundleURL.appendingPathComponent("tessdata")
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: destURL.path) {
            do {
                try fileManager.createSymbolicLink(at: destURL, withDestinationURL: sourceURL)
            } catch {
                print("Failed to link tessdata: \(error)")
            }
        }
    }
}