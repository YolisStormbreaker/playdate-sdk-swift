// MARK: - Video Debug Info

/// Debug information for video player
///
/// Contains current video info, error state, player state, and FPS.
/// Used for debug overlay rendering.
///
/// Example:
/// ```swift
/// let debug = player.debugInfo
/// print("State: \(debug.state)")
/// print("Frame: \(debug.info.currentFrame)")
/// print("FPS: \(debug.fps)")
/// if let error = debug.lastError {
///     print("Error: \(error)")
/// }
/// ```
public struct VideoDebugInfo {
    /// Current video information
    public let info: VideoInfo

    /// Last error that occurred (if any)
    public let lastError: GraphicsError?

    /// Current player state
    public let state: VideoPlayerState

    /// Target frame rate from video
    public let fps: Float

    /// Initialize debug info
    public init(
        info: VideoInfo,
        lastError: GraphicsError?,
        state: VideoPlayerState,
        fps: Float
    ) {
        self.info = info
        self.lastError = lastError
        self.state = state
        self.fps = fps
    }

    /// Format as compact debug string
    public var compactDescription: String {
        let errorStr = lastError.map { " ERROR: \($0)" } ?? ""
        return "[\(state)] Frame: \(info.currentFrame)/\(info.frameCount) | FPS: \(fps.string)\(errorStr)"
    }
}

// MARK: - CustomStringConvertible Extensions

extension VideoDebugInfo: CustomStringConvertible {
    public var description: String {
        var result = """
        VideoDebugInfo:
          State: \(state)
          FPS: \(fps.string)
        """

        result += "\n  " + info.description.replacing("\n", with: "\n  ")

        if let error = lastError {
            result += "\n  Last Error: \(error)"
        }

        return result
    }
}
