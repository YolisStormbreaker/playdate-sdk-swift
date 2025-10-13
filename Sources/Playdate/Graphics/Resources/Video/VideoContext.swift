// MARK: - Video Context

/// Rendering context for video playback
///
/// Specifies where video frames should be rendered:
/// - `.screen` - Direct to display buffer
/// - `.bitmap(Bitmap)` - To custom bitmap for composition
///
/// Example:
/// ```swift
/// // Render to screen
/// let player = VideoPlayer(path: "intro.pdv", context: .screen)
///
/// // Render to custom bitmap for effects
/// let renderTarget = Bitmap(width: 400, height: 240)
/// let player = VideoPlayer(path: "background.pdv", context: .bitmap(renderTarget))
/// ```
public enum VideoContext {
    /// Render directly to screen (display buffer)
    case screen

    /// Render to custom bitmap
    /// - Parameter bitmap: Target bitmap for rendering
    case bitmap(Bitmap)
}
