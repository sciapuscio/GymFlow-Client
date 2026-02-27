// Stub types for mobile_scanner on platforms that don't support it (Windows, web).
// On mobile, the real mobile_scanner is used instead via conditional import in scanner_stub.dart

class BarcodeCapture {
  final List<Barcode> barcodes;
  const BarcodeCapture({this.barcodes = const []});
}

class Barcode {
  final String? rawValue;
  const Barcode({this.rawValue});
}

class MobileScannerController {
  Future<void> stop() async {}
  Future<void> toggleTorch() async {}
  void dispose() {}
}

class BarcodeErrorBuilder {
  const BarcodeErrorBuilder();
}
