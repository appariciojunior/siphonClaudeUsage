import SwiftUI

/// Phosphor "Drop" icon (regular weight) — MIT licensed, phosphoricons.com
/// SVG viewBox 0 0 256 256, scaled to fit the given frame.
struct PhosphorDrop: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width  / 256
        let scaleY = rect.height / 256

        var path = Path()

        // Outer teardrop
        path.move(to:    .init(x: 174 * scaleX, y: 47.75 * scaleY))
        path.addCurve(to: .init(x: 82  * scaleX, y: 47.75 * scaleY),
                     control1: .init(x: 156.2 * scaleX, y: 21.4  * scaleY),
                     control2: .init(x: 99.8  * scaleX, y: 21.4  * scaleY))
        path.addCurve(to: .init(x: 40  * scaleX, y: 144  * scaleY),
                     control1: .init(x: 54.51 * scaleX, y: 79.32 * scaleY),
                     control2: .init(x: 40    * scaleX, y: 112.6 * scaleY))
        path.addCurve(to: .init(x: 216 * scaleX, y: 144  * scaleY),
                     control1: .init(x: 40  * scaleX, y: 188   * scaleY),
                     control2: .init(x: 216 * scaleX, y: 188   * scaleY))
        path.addCurve(to: .init(x: 174 * scaleX, y: 47.75 * scaleY),
                     control1: .init(x: 216  * scaleX, y: 112.6 * scaleY),
                     control2: .init(x: 201.49 * scaleX, y: 79.32 * scaleY))
        path.closeSubpath()

        return path
    }
}

#Preview {
    HStack(spacing: 20) {
        PhosphorDrop().fill(.orange).frame(width: 16, height: 16)
        PhosphorDrop().fill(.orange).frame(width: 24, height: 24)
        PhosphorDrop().fill(.orange).frame(width: 40, height: 40)
    }
    .padding()
}
