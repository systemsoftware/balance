import SwiftUI

struct BackgroundShape: Shape {
    @AppStorage("backgroundShape", store: Config.sharedDefaults)
    private var backgroundShape = 0

    var cornerRadius: CGFloat = 10

    init(cornerRadius: CGFloat = 10) {
        self.cornerRadius = cornerRadius
    }

    func path(in rect: CGRect) -> Path {
        switch backgroundShape {
        case 1:
            return RoundedRectangle(cornerRadius: cornerRadius)
                .path(in: rect)

        case 2:
            return Rectangle().path(in: rect)

        default:
            return Capsule().path(in: rect)
        }
    }
}
