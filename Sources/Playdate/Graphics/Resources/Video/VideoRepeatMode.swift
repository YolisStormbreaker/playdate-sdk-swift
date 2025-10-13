// MARK: - Video Repeat Mode

/// Defines how video should repeat after reaching end
///
/// Example:
/// ```swift
/// var player = VideoPlayer(path: "loop.pdv")
///
/// // Play once
/// player.repeatMode = .once
///
/// // Loop 3 times
/// player.repeatMode = .repeatCount(3)
///
/// // Loop forever
/// player.repeatMode = .loopForever
/// ```
public enum VideoRepeatMode: Equatable {
    /// Play once and stop at end
    case once

    /// Repeat N times (total plays = count + 1)
    /// - Parameter count: Number of additional plays after first
    case repeatCount(Int32)

    /// Loop indefinitely
    case loopForever

    /// Check if mode involves looping
    public var isLooping: Bool {
        switch self {
        case .once:
            return false
        case .repeatCount, .loopForever:
            return true
        }
    }

    /// Get total number of plays (nil for loopForever)
    public var totalPlays: Int32? {
        switch self {
        case .once:
            return 1
        case let .repeatCount(count):
            return count + 1
        case .loopForever:
            return nil
        }
    }
}
