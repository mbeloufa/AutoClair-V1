import Flutter
import UserNotifications
import UIKit
import VisionKit

@main
@objc class AppDelegate: FlutterAppDelegate,
  FlutterImplicitEngineDelegate,
  VNDocumentCameraViewControllerDelegate {

  private static let scannerChannelName =
    "fr.autoclair/document_scanner"
  private static let scannerMethodName = "scanDocument"
  private static let maximumPageCount = 10
  private static let temporaryFileLifetime: TimeInterval =
    24 * 60 * 60

  private var scannerChannel: FlutterMethodChannel?
  private var pendingScannerResult: FlutterResult?
  private weak var presentedScanner:
    VNDocumentCameraViewController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions:
      [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate =
        self as? UNUserNotificationCenterDelegate
    }
    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }

  func didInitializeImplicitFlutterEngine(
    _ engineBridge: FlutterImplicitEngineBridge
  ) {
    GeneratedPluginRegistrant.register(
      with: engineBridge.pluginRegistry
    )

    let channel = FlutterMethodChannel(
      name: Self.scannerChannelName,
      binaryMessenger:
        engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler {
      [weak self] call, result in
      guard call.method == Self.scannerMethodName else {
        result(FlutterMethodNotImplemented)
        return
      }

      self?.startDocumentScan(result: result)
    }

    scannerChannel = channel
  }

  private func startDocumentScan(
    result: @escaping FlutterResult
  ) {
    guard pendingScannerResult == nil else {
      result(
        FlutterError(
          code: "SCAN_IN_PROGRESS",
          message: "Un scan est déjà en cours.",
          details: nil
        )
      )
      return
    }

    guard VNDocumentCameraViewController.isSupported else {
      result(
        FlutterError(
          code: "SCANNER_UNSUPPORTED",
          message:
            "Le scanner de documents n'est pas compatible "
            + "avec cet appareil.",
          details: nil
        )
      )
      return
    }

    guard let presenter = activeViewController() else {
      result(
        FlutterError(
          code: "SCANNER_START_FAILED",
          message:
            "L'écran du scanner ne peut pas être affiché.",
          details: nil
        )
      )
      return
    }

    pendingScannerResult = result

    let scanner = VNDocumentCameraViewController()
    scanner.delegate = self
    scanner.modalPresentationStyle = .fullScreen
    presentedScanner = scanner

    presenter.present(
      scanner,
      animated: true
    )
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFinishWith scan: VNDocumentCameraScan
  ) {
    controller.dismiss(animated: true) {
      [weak self] in
      self?.presentedScanner = nil
      self?.prepareScanResult(scan)
    }
  }

  func documentCameraViewControllerDidCancel(
    _ controller: VNDocumentCameraViewController
  ) {
    controller.dismiss(animated: true) {
      [weak self] in
      self?.presentedScanner = nil
      self?.finishScanSuccessfully(value: nil)
    }
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFailWithError error: Error
  ) {
    controller.dismiss(animated: true) {
      [weak self] in
      self?.presentedScanner = nil
      self?.finishScanWithError(
        code: "SCAN_RESULT_FAILED",
        message:
          error.localizedDescription.isEmpty
          ? "Le document n'a pas pu être numérisé."
          : error.localizedDescription
      )
    }
  }

  private func prepareScanResult(
    _ scan: VNDocumentCameraScan
  ) {
    guard scan.pageCount > 0 else {
      finishScanWithError(
        code: "PDF_UNAVAILABLE",
        message:
          "Le scanner n'a produit aucune page."
      )
      return
    }

    guard scan.pageCount <= Self.maximumPageCount else {
      finishScanWithError(
        code: "SCAN_TOO_MANY_PAGES",
        message:
          "Le document contient plus de 10 pages. "
          + "Recommencez le scan avec 10 pages maximum."
      )
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      [weak self] in
      guard let self else {
        return
      }

      do {
        let outputUrl = try self.createPdf(from: scan)
        let attributes = try FileManager.default.attributesOfItem(
          atPath: outputUrl.path
        )
        let size =
          (attributes[.size] as? NSNumber)?.int64Value ?? 0

        guard size > 0 else {
          try? FileManager.default.removeItem(at: outputUrl)
          throw ScannerError.emptyPdf
        }

        let response: [String: Any] = [
          "path": outputUrl.path,
          "name": outputUrl.lastPathComponent,
          "size": size,
          "pageCount": scan.pageCount,
        ]

        DispatchQueue.main.async {
          self.finishScanSuccessfully(value: response)
        }
      } catch {
        DispatchQueue.main.async {
          self.finishScanWithError(
            code: "SCAN_FILE_FAILED",
            message:
              "Le PDF numérisé n'a pas pu être préparé."
          )
        }
      }
    }
  }

  private func createPdf(
    from scan: VNDocumentCameraScan
  ) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "autoclair_document_scans",
        isDirectory: true
      )

    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )

    cleanExpiredScans(in: directory)

    let outputUrl = directory.appendingPathComponent(
      "autoclair_scan_\(UUID().uuidString).pdf"
    )

    let pageBounds = CGRect(
      x: 0,
      y: 0,
      width: 595,
      height: 842
    )
    let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
    let pageContentBounds = pageBounds.insetBy(
      dx: 24,
      dy: 24
    )

    let pdfData = renderer.pdfData {
      rendererContext in
      for pageIndex in 0..<scan.pageCount {
        autoreleasepool {
          rendererContext.beginPage()

          UIColor.white.setFill()
          rendererContext.cgContext.fill(pageBounds)

          let sourceImage = scan.imageOfPage(
            at: pageIndex
          )
          let preparedImage =
            prepareImageForPdf(sourceImage)
          let drawingRect = aspectFitRect(
            imageSize: preparedImage.size,
            inside: pageContentBounds
          )

          preparedImage.draw(in: drawingRect)
        }
      }
    }

    guard !pdfData.isEmpty else {
      throw ScannerError.emptyPdf
    }

    try pdfData.write(
      to: outputUrl,
      options: .atomic
    )

    return outputUrl
  }

  private func prepareImageForPdf(
    _ image: UIImage
  ) -> UIImage {
    let maximumPixelDimension: CGFloat = 2_000
    let pixelWidth = image.size.width * image.scale
    let pixelHeight = image.size.height * image.scale
    let largestDimension = max(pixelWidth, pixelHeight)

    let resizeRatio =
      largestDimension > maximumPixelDimension
      ? maximumPixelDimension / largestDimension
      : 1

    let targetSize = CGSize(
      width: max(1, pixelWidth * resizeRatio),
      height: max(1, pixelHeight * resizeRatio)
    )

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true

    let resizedImage = UIGraphicsImageRenderer(
      size: targetSize,
      format: format
    ).image {
      context in
      UIColor.white.setFill()
      context.fill(
        CGRect(
          origin: .zero,
          size: targetSize
        )
      )
      image.draw(
        in: CGRect(
          origin: .zero,
          size: targetSize
        )
      )
    }

    guard
      let jpegData = resizedImage.jpegData(
        compressionQuality: 0.76
      ),
      let compressedImage = UIImage(data: jpegData)
    else {
      return resizedImage
    }

    return compressedImage
  }

  private func aspectFitRect(
    imageSize: CGSize,
    inside bounds: CGRect
  ) -> CGRect {
    guard
      imageSize.width > 0,
      imageSize.height > 0
    else {
      return bounds
    }

    let scale = min(
      bounds.width / imageSize.width,
      bounds.height / imageSize.height
    )
    let width = imageSize.width * scale
    let height = imageSize.height * scale

    return CGRect(
      x: bounds.midX - width / 2,
      y: bounds.midY - height / 2,
      width: width,
      height: height
    )
  }

  private func cleanExpiredScans(
    in directory: URL
  ) {
    let expirationDate = Date().addingTimeInterval(
      -Self.temporaryFileLifetime
    )

    guard
      let files = try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [
          .contentModificationDateKey,
          .isRegularFileKey,
        ],
        options: [.skipsHiddenFiles]
      )
    else {
      return
    }

    for file in files {
      guard
        let values = try? file.resourceValues(
          forKeys: [
            .contentModificationDateKey,
            .isRegularFileKey,
          ]
        ),
        values.isRegularFile == true,
        let modificationDate =
          values.contentModificationDate,
        modificationDate < expirationDate
      else {
        continue
      }

      try? FileManager.default.removeItem(at: file)
    }
  }

  private func activeViewController()
    -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }

    let activeScene =
      scenes.first {
        $0.activationState == .foregroundActive
      }
      ?? scenes.first {
        $0.activationState == .foregroundInactive
      }

    let window =
      activeScene?.windows.first {
        $0.isKeyWindow
      }
      ?? activeScene?.windows.first {
        !$0.isHidden
      }

    guard let root = window?.rootViewController else {
      return nil
    }

    return topViewController(from: root)
  }

  private func topViewController(
    from viewController: UIViewController
  ) -> UIViewController {
    if let presented =
      viewController.presentedViewController {
      return topViewController(from: presented)
    }

    if let navigationController =
      viewController as? UINavigationController,
      let visible =
        navigationController.visibleViewController {
      return topViewController(from: visible)
    }

    if let tabController =
      viewController as? UITabBarController,
      let selected =
        tabController.selectedViewController {
      return topViewController(from: selected)
    }

    return viewController
  }

  private func finishScanSuccessfully(
    value: Any?
  ) {
    guard let result = pendingScannerResult else {
      return
    }

    pendingScannerResult = nil
    result(value)
  }

  private func finishScanWithError(
    code: String,
    message: String
  ) {
    guard let result = pendingScannerResult else {
      return
    }

    pendingScannerResult = nil
    result(
      FlutterError(
        code: code,
        message: message,
        details: nil
      )
    )
  }
}

private enum ScannerError: Error {
  case emptyPdf
}
