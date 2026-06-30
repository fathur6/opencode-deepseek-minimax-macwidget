import SwiftUI

public enum DesignSystem {
    public enum Typography {
        public static let displayLarge: CGFloat = 24
        public static let displayMedium: CGFloat = 18
        public static let headingLarge: CGFloat = 16
        public static let headingMedium: CGFloat = 14
        public static let bodyLarge: CGFloat = 13
        public static let bodyMedium: CGFloat = 12
        public static let caption: CGFloat = 11
        public static let captionSmall: CGFloat = 10
    }

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Radius {
        public static let sm: CGFloat = 4
        public static let md: CGFloat = 6
        public static let lg: CGFloat = 10
        public static let xl: CGFloat = 16
        public static let full: CGFloat = 9999
    }

    public enum Color {
        public static let safe = SwiftUI.Color.green
        public static let warning = SwiftUI.Color.orange
        public static let critical = SwiftUI.Color.red
        public static let deepseekAccent = SwiftUI.Color.blue
        public static let minimaxAccent = SwiftUI.Color.green
    }
}
