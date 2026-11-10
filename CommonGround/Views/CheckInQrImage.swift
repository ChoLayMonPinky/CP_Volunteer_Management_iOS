import CoreImage.CIFilterBuiltins
import SwiftUI

struct CheckInQrImage: View {
    let code: String
    var size: CGFloat = 180

    var body: some View {
        Group {
            if let image = Self.makeQR(from: code) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ProgressView()
                    .frame(width: size, height: size)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private static func makeQR(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
