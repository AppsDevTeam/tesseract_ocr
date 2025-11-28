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

        if call.method == "extractText" || call.method == "extractHocr" {
            guard let args = call.arguments else {
                result("iOS could not recognize flutter arguments in method: (sendParams)")
                return
            }

            let params = args as! [String: Any]
            let language: String? = params["language"] as? String

            var swiftyTesseract = SwiftyTesseract(language: .english)
            if let language = language {
                swiftyTesseract = SwiftyTesseract(language: .custom(language))
            }

            if let imageBytes = params["imageBytes"] as? FlutterStandardTypedData {
                if let imageData = imageBytes.data {
                    if let image = UIImage(data: imageData) {
                        performOcr(on: image, method: call.method, swiftyTesseract: swiftyTesseract, result: result)
                    } else {
                        result("Failed to decode image from imageBytes")
                    }
                }
            } else if let imagePath = params["imagePath"] as? String {
                guard let image = UIImage(contentsOfFile: imagePath) else {
                    result("Failed to load image from imagePath")
                    return
                }
                performOcr(on: image, method: call.method, swiftyTesseract: swiftyTesseract, result: result)
            } else {
                result("You must provide either imagePath or imageBytes")
            }
        }
    }

    func performOcr(on image: UIImage, method: String, swiftyTesseract: SwiftyTesseract, result: @escaping FlutterResult) {
        swiftyTesseract.performOCR(on: image) { recognizedString in
            guard let recognizedString = recognizedString else {
                result("OCR failed to extract text")
                return
            }
            if method == "extractHocr" {
                let hocrString = swiftyTesseract.hocrString(for: image)
                result(hocrString)
            } else {
                result(recognizedString)
            }
        }
    }

    func initializeTessData() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let destURL = documentsURL!.appendingPathComponent("tessdata")
        let sourceURL = Bundle.main.bundleURL.appendingPathComponent("tessdata")
        let fileManager = FileManager.default

        do {
            try fileManager.createSymbolicLink(at: sourceURL, withDestinationURL: destURL)
        } catch {
            print(error)
        }
    }
}