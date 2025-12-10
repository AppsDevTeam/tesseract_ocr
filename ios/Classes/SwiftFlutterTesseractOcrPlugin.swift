import Flutter
import UIKit
import SwiftyTesseract

// Custom data source pro SwiftyTesseract – ukazuje na cestu, kde leží *.traineddata
struct FileSystemTessDataSource: TessDataSource {
    let pathToTrainedData: String
}

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
        guard call.method == "extractText" || call.method == "extractHocr" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard let args = call.arguments as? [String: Any] else {
            result("iOS could not recognize flutter arguments in method: (sendParams)")
            return
        }

        guard let tessDataParentPath = args["tessData"] as? String, !tessDataParentPath.isEmpty else {
            result("Missing tessData path")
            return
        }

        let tessdataPath = (tessDataParentPath as NSString).appendingPathComponent("tessdata")

        let languageParam = (args["language"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let languageString = (languageParam?.isEmpty == false) ? languageParam! : "eng"

        let dataSource = FileSystemTessDataSource(pathToTrainedData: tessdataPath)
        let tesseract = SwiftyTesseract(
            language: .custom(languageString),
            dataSource: dataSource
        )

        if let imageBytes = args["imageBytes"] as? FlutterStandardTypedData {
            guard let image = UIImage(data: imageBytes.data) else {
                result("Failed to decode image from imageBytes")
                return
            }
            performOcr(on: image, method: call.method, tesseract: tesseract, result: result)

        } else if let imagePath = args["imagePath"] as? String, !imagePath.isEmpty {
            guard let image = UIImage(contentsOfFile: imagePath) else {
                result("Failed to load image from imagePath")
                return
            }
            performOcr(on: image, method: call.method, tesseract: tesseract, result: result)

        } else {
            result("You must provide either imagePath or imageBytes")
        }
    }

    func performOcr(
        on image: UIImage,
        method: String,
        tesseract: SwiftyTesseract,
        result: @escaping FlutterResult
    ) {
        tesseract.performOCR(on: image) { recognizedString in
            guard let recognizedString = recognizedString else {
                result("OCR failed to extract text")
                return
            }

            result(recognizedString)
        }
    }
}