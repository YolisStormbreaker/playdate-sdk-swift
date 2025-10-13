// MARK: - Video Info Structure

/// Information about a video file
///
/// Contains dimensions, frame rate, frame count, and current position.
/// Updated automatically during playback.
///
/// Example:
/// ```swift
/// let info = player.info
/// print("Video: \(info.path ?? "unknown")")
/// print("Size: \(info.width)x\(info.height)")
/// print("Frames: \(info.currentFrame)/\(info.frameCount)")
/// print("Duration: \(info.duration) seconds")
/// print("Progress: \(info.progress * 100)%")
/// ```
public struct VideoInfo: Equatable {
    // MARK: - Basic Properties

    /// File path of the video
    public let path: String?

    /// Width in pixels
    public let width: Int32

    /// Height in pixels
    public let height: Int32

    /// Frame rate (frames per second)
    public let frameRate: Float

    /// Total number of frames in video
    public let frameCount: Int32

    /// Current frame number (0-based)
    public let currentFrame: Int32

    // MARK: - Computed Properties

    /// Video dimensions as Size
    public var size: Size {
        return Size(width: width, height: height)
    }

    /// Total duration in seconds
    public var duration: Float {
        guard frameRate > 0 else { return 0 }
        return Float(frameCount) / frameRate
    }

    /// Current playback position in seconds
    public var currentSeconds: Float {
        guard frameRate > 0 else { return 0 }
        return Float(currentFrame) / frameRate
    }

    /// Playback progress (0.0 - 1.0)
    public var progress: Float {
        guard frameCount > 0 else { return 0 }
        return Float(currentFrame) / Float(frameCount)
    }

    /// Remaining frames
    public var remainingFrames: Int32 {
        return max(0, frameCount - currentFrame)
    }

    /// Remaining time in seconds
    public var remainingSeconds: Float {
        guard frameRate > 0 else { return 0 }
        return Float(remainingFrames) / frameRate
    }

    /// Check if at start (frame 0)
    public var isAtStart: Bool {
        return currentFrame == 0
    }

    /// Check if at end (last frame)
    public var isAtEnd: Bool {
        return currentFrame >= frameCount - 1
    }

    // MARK: - Initialization

    /// Create video info
    public init(
        path: String?,
        width: Int32,
        height: Int32,
        frameRate: Float,
        frameCount: Int32,
        currentFrame: Int32
    ) {
        self.path = path
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.frameCount = frameCount
        self.currentFrame = currentFrame
    }
}

// MARK: - CustomStringConvertible Extensions

extension VideoInfo: CustomStringConvertible {
    public var description: String {
        let pathStr = path.map { " '\($0)'" } ?? ""
        return """
        VideoInfo\(pathStr):
          Size: \(width)x\(height)
          Frame Rate: \(frameRate.string) fps
          Frames: \(currentFrame)/\(frameCount)
          Duration: \(duration.string)s
          Progress: \(Int(progress * 100))%
        """
    }
}
