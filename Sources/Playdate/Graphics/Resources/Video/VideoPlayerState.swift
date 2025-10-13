// VideoPlayerState.swift
// Fixed version without String rawValue to avoid Unicode normalization issues

import CPlaydate

/// State of video player
///
/// # State Transitions
///
/// ```
/// idle → playing → paused → playing → finished
///   ↓       ↓        ↓
/// stopped ← stopped ← stopped
/// ```
public enum VideoPlayerState: Int, CustomStringConvertible {
    /// Player created but not started
    case idle = 0

    /// Actively playing video
    case playing = 1

    /// Playback paused, can resume
    case paused = 2

    /// Playback stopped, rewound to start
    case stopped = 3

    /// Video finished playing
    case finished = 4

    /// CustomStringConvertible conformance
    public var description: String {
        switch self {
        case .idle: return "idle"
        case .playing: return "playing"
        case .paused: return "paused"
        case .stopped: return "stopped"
        case .finished: return "finished"
        }
    }
}

// MARK: - State Queries

public extension VideoPlayerState {
    /// Check if player is in active playback state
    var isPlaying: Bool {
        return self == .playing
    }

    /// Check if player is paused
    var isPaused: Bool {
        return self == .paused
    }

    /// Check if player is stopped
    var isStopped: Bool {
        return self == .stopped
    }

    /// Check if video has finished
    var isFinished: Bool {
        return self == .finished
    }

    /// Check if player is idle (never started)
    var isIdle: Bool {
        return self == .idle
    }

    /// Check if player can resume playback
    var canResume: Bool {
        return self == .paused || self == .stopped
    }

    /// Check if player is in any active state (playing or paused)
    var isActive: Bool {
        return self == .playing || self == .paused
    }
}

// MARK: - Equatable (automatically derived for Int-based enum)

// No need for explicit Equatable conformance - Int enums are automatically Equatable
// and comparison is done via integer values, avoiding String operations
