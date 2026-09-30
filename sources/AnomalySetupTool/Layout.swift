import CoreGraphics

enum Layout {
    /// The window stays compact; grouped forms scroll when their content expands.
    static let windowWidth: CGFloat = 820
    static let windowHeight: CGFloat = 580
    /// Fits the progress summary, stages, USVFS status, and collapsed log output.
    static let creationWindowHeight: CGFloat = 660
    /// Left edge of the page title: where the grouped forms below it start.
    static let titleHorizontalPadding: CGFloat = 58
}
