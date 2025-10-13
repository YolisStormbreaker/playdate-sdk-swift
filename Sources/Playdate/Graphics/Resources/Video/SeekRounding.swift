// MARK: - Seek Rounding Mode

/// Rounding mode for seek operations by time
///
/// When seeking to fractional seconds, determines how to
/// round to the nearest frame number.
///
/// Example:
/// ```swift
/// // Video at 30fps, seeking to 1.52 seconds
/// player.seek(toSeconds: 1.52, rounding: .down)     // → frame 45
/// player.seek(toSeconds: 1.52, rounding: .nearest)  // → frame 46
/// player.seek(toSeconds: 1.52, rounding: .up)       // → frame 46
/// ```
public enum SeekRounding {
    /// Round down (floor) to previous frame
    case down

    /// Round to nearest frame
    case nearest

    /// Round up (ceil) to next frame
    case up

    /// Apply rounding to fractional value
    /// - Parameter value: Fractional frame number
    /// - Returns: Rounded frame number
    func apply(to value: Float) -> Int32 {
        switch self {
        case .down:
            return Int32(value)
        case .nearest:
            return Int32(value + 0.5)
        case .up:
            return Int32(value + 0.999)
        }
    }
}
