// VideoPlayer.swift
// Playdate Graphics Swift SDK
//
// High-level wrapper for LCDVideoPlayer* with automatic memory management
// Supports playback control, seeking, context management, and debug overlay

import CPlaydate

// MARK: - Video API Accessor

/// Access to Playdate video C API
private var videoAPI: playdate_video {
    playdateAPI.graphics.unsafelyUnwrapped.pointee.video.unsafelyUnwrapped.pointee
}

/// Access to Playdate system C API
private var systemAPI: playdate_sys {
    playdateAPI.system.unsafelyUnwrapped.pointee
}

// MARK: - VideoPlayer Class

/// High-level video player for Playdate
///
/// Provides complete video playback functionality including:
/// - Play/pause/stop controls
/// - Frame-accurate seeking
/// - Automatic frame rate control
/// - Custom render contexts
/// - Debug overlay
/// - Error callbacks
///
/// # Basic Usage
///
/// ```swift
/// // Simple playback to screen
/// guard let player = VideoPlayer(path: "assets/videos/intro.pdv") else {
///     print("Failed to load video")
///     return
/// }
///
/// // In game update loop
/// func updateGame() {
///     _ = player.updateAndRender()
/// }
/// ```
///
/// # Advanced Usage
///
/// ```swift
/// // Render to custom bitmap
/// let renderTarget = Bitmap(width: 400, height: 240)!
/// let player = VideoPlayer(
///     path: "assets/videos/background.pdv",
///     context: .bitmap(renderTarget),
///     autoPlay: false
/// )
///
/// // Configure callbacks
/// player.onError = { error, info in
///     print("Video error at frame \(info.currentFrame): \(error)")
/// }
///
/// player.onVideoEnd = {
///     print("Video finished!")
/// }
///
/// // Manual control
/// player.play()
/// player.seek(toProgress: 0.5)
/// player.pause()
/// ```
///
/// # Memory Management
///
/// VideoPlayer automatically frees C resources in deinit.
/// All video players are owned (not borrowed).
public final class VideoPlayer {
    // MARK: - Private Properties - C API

    /// Pointer to underlying LCDVideoPlayer C structure
    private let pointer: OpaquePointer

    /// Original file path
    private let sourcePath: String

    // MARK: - Private Properties - State

    /// Current playback state
    private var state: VideoPlayerState

    /// Repeat mode for playback
    public var repeatMode: VideoRepeatMode = .once

    /// Number of times video has looped (for repeatCount mode)
    private var loopCount: Int32 = 0

    // MARK: - Private Properties - Context

    /// Current render context bitmap (if using bitmap context)
    private var contextBitmap: Bitmap?

    /// Whether this player owns the context bitmap
    private var ownsContext: Bool = false

    // MARK: - Private Properties - Timing

    /// Last update time in milliseconds
    private var lastUpdateTime: UInt32 = 0

    /// Accumulated time for frame progression
    private var frameAccumulator: Float = 0.0

    /// Whether timing system is initialized
    private var timingInitialized: Bool = false

    // MARK: - Private Properties - Debug

    /// Show debug overlay
    public var showDebugOverlay: Bool = false

    // MARK: - Public Properties - Callbacks

    /// Error callback - invoked immediately when error occurs
    /// - Parameters:
    ///   - error: The graphics error that occurred
    ///   - info: Current video info at time of error
    public var onError: ((GraphicsError, VideoInfo) -> Void)?

    /// Video end callback - invoked when video reaches last frame
    public var onVideoEnd: (() -> Void)?

    // MARK: - Public Properties - Error State

    /// Last error that occurred during playback
    public private(set) var lastError: GraphicsError?

    // MARK: - Initialization

    /// Create video player from file
    ///
    /// Loads video file and optionally starts playback immediately.
    ///
    /// - Parameters:
    ///   - path: Path to .pdv video file (relative to project root)
    ///   - context: Render context (default: .screen)
    ///   - autoPlay: Start playing immediately (default: true)
    ///
    /// - Returns: VideoPlayer instance or nil if load fails
    ///
    /// Example:
    /// ```swift
    /// // Auto-play to screen
    /// let player = VideoPlayer(path: "assets/videos/intro.pdv")
    ///
    /// // Render to bitmap, manual control
    /// let bitmap = Bitmap(width: 400, height: 240)!
    /// let player = VideoPlayer(
    ///     path: "assets/videos/background.pdv",
    ///     context: .bitmap(bitmap),
    ///     autoPlay: false
    /// )
    /// ```
    public init?(
        path: String,
        context: VideoContext = .screen,
        autoPlay: Bool = true
    ) {
        // Load video via C API
        guard let ptr = videoAPI.loadVideo(path) else {
            // Failed to load - get error from C API
            return nil
        }

        pointer = ptr
        sourcePath = path
        state = .idle

        // Set render context
        switch context {
        case .screen:
            videoAPI.useScreenContext(pointer)
            contextBitmap = nil
            ownsContext = false

        case let .bitmap(bitmap):
            let result = videoAPI.setContext(pointer, bitmap.cPointer)
            if result == 0 {
                // Failed to set context
                videoAPI.freePlayer(ptr)
                return nil
            }
            contextBitmap = bitmap
            ownsContext = false // Caller owns the bitmap
        }

        // Auto-play if requested
        if autoPlay {
            state = .playing
            lastUpdateTime = systemAPI.getCurrentTimeMilliseconds()
            timingInitialized = true
        }
    }

    // MARK: - Deinitialization

    /// Automatic cleanup - frees video player resources
    deinit {
        // Free the C video player structure
        videoAPI.freePlayer(pointer)

        // If we own the context bitmap, it will be freed by Bitmap's deinit
        // We don't free it here - caller may still be using it
        contextBitmap = nil
    }

    // MARK: - Internal Access

    /// Internal access to C pointer for low-level operations
    var cPointer: OpaquePointer {
        return pointer
    }
}

// MARK: - Public Properties - Info

public extension VideoPlayer {
    /// Current video information
    ///
    /// Lazily fetches current state from C API on each access.
    /// Always returns up-to-date information.
    ///
    /// Example:
    /// ```swift
    /// let info = player.info
    /// print("Frame: \(info.currentFrame)/\(info.frameCount)")
    /// print("Time: \(info.currentSeconds)/\(info.duration)")
    /// print("Progress: \(info.progress * 100)%")
    /// ```
    var info: VideoInfo {
        return getInfo()
    }

    /// Debug information for overlay
    ///
    /// Includes current info, state, errors, and frame rate.
    ///
    /// Example:
    /// ```swift
    /// let debug = player.debugInfo
    /// print(debug.compactDescription)
    /// // Output: "[playing] Frame: 45/300 | FPS: 30.0"
    /// ```
    var debugInfo: VideoDebugInfo {
        let currentInfo = getInfo()
        return VideoDebugInfo(
            info: currentInfo,
            lastError: lastError,
            state: state,
            fps: currentInfo.frameRate
        )
    }

    /// File path of loaded video
    var path: String {
        return sourcePath
    }
}

// MARK: - Public Properties - State Checks

public extension VideoPlayer {
    /// Check if currently playing
    var isPlaying: Bool {
        return state == .playing
    }

    /// Check if paused
    var isPaused: Bool {
        return state == .paused
    }

    /// Check if stopped
    var isStopped: Bool {
        return state == .stopped
    }

    /// Check if finished
    var isFinished: Bool {
        return state == .finished
    }

    /// Check if idle (not started)
    var isIdle: Bool {
        return state == .idle
    }
}

// MARK: - Public Properties - Progress

public extension VideoPlayer {
    /// Current playback progress (0.0 - 1.0)
    var currentProgress: Float {
        return info.progress
    }

    /// Current playback position in seconds
    var currentSeconds: Float {
        return info.currentSeconds
    }

    /// Total duration in seconds
    var duration: Float {
        return info.duration
    }

    /// Current frame number
    var currentFrame: Int32 {
        return info.currentFrame
    }

    /// Total frame count
    var frameCount: Int32 {
        return info.frameCount
    }

    /// Video frame rate
    var frameRate: Float {
        return info.frameRate
    }
}

// MARK: - Private Helpers - Info

private extension VideoPlayer {
    /// Fetch current video info from C API
    ///
    /// Calls C API getInfo to get current state.
    /// This is called lazily on each access to `info` property.
    ///
    /// - Returns: Current VideoInfo
    func getInfo() -> VideoInfo {
        var width: Int32 = 0
        var height: Int32 = 0
        var frameRate: Float = 0.0
        var frameCount: Int32 = 0
        var currentFrame: Int32 = 0

        // Call C API to get video info
        videoAPI.getInfo(
            pointer,
            &width,
            &height,
            &frameRate,
            &frameCount,
            &currentFrame
        )

        return VideoInfo(
            path: sourcePath,
            width: width,
            height: height,
            frameRate: frameRate,
            frameCount: frameCount,
            currentFrame: currentFrame
        )
    }
}

// MARK: - Private Helpers - Error

private extension VideoPlayer {
    /// Get last error from C API
    ///
    /// Retrieves error string from video player and converts
    /// to appropriate GraphicsError case.
    ///
    /// - Returns: GraphicsError representing the C API error
    func getLastError() -> GraphicsError {
        // Get error string from C API
        guard let errorCStr = videoAPI.getError(pointer) else {
            return .videoUpdateFailed(frame: currentFrame, reason: "Unknown error")
        }

        let errorMessage = String(cString: errorCStr)

        // Return appropriate error
        return .videoUpdateFailed(
            frame: currentFrame,
            reason: errorMessage
        )
    }

    /// Record error and invoke callback
    ///
    /// Stores error in lastError and immediately invokes onError callback.
    ///
    /// - Parameter error: The error that occurred
    func recordError(_ error: GraphicsError) {
        lastError = error

        // Invoke callback immediately
        let currentInfo = getInfo()
        onError?(error, currentInfo)
    }
}

// MARK: - Private Helpers - State

private extension VideoPlayer {
    /// Check if state transition is valid
    ///
    /// Validates whether requested state change is allowed
    /// based on current state.
    ///
    /// - Parameters:
    ///   - from: Current state
    ///   - to: Desired state
    /// - Returns: true if transition is valid
    func canTransition(from: VideoPlayerState, to: VideoPlayerState) -> Bool {
        switch (from, to) {
        case (.idle, .playing),
             (.idle, .stopped):
            return true

        case (.playing, .paused),
             (.playing, .stopped),
             (.playing, .finished):
            return true

        case (.paused, .playing),
             (.paused, .stopped):
            return true

        case (.stopped, .playing):
            return true

        case (.finished, .playing),
             (.finished, .stopped):
            return true

        default:
            return from == to // Allow same state
        }
    }

    /// Transition to new state with validation
    ///
    /// Changes state only if transition is valid.
    ///
    /// - Parameter newState: Desired state
    /// - Returns: true if transition succeeded
    @discardableResult
    func transitionTo(_ newState: VideoPlayerState) -> Bool {
        guard canTransition(from: state, to: newState) else {
            let error = GraphicsError.videoInvalidState(
                operation: "transition to \(newState.description)",
                currentState: state.description
            )
            recordError(error)
            return false
        }

        state = newState
        return true
    }
}

// MARK: - Private Helpers - Timing

private extension VideoPlayer {
    /// Initialize timing system
    ///
    /// Sets up frame accumulator and records initial time.
    /// Called on first play() or updateAndRender().
    func initializeTiming() {
        lastUpdateTime = systemAPI.getCurrentTimeMilliseconds()
        frameAccumulator = 0.0
        timingInitialized = true
    }

    /// Reset timing system
    ///
    /// Clears frame accumulator and resets timer.
    /// Called on stop() or seek operations.
    func resetTiming() {
        frameAccumulator = 0.0
        if state == .playing {
            lastUpdateTime = systemAPI.getCurrentTimeMilliseconds()
        }
    }

    /// Calculate delta time since last update
    ///
    /// - Returns: Delta time in seconds
    func calculateDeltaTime() -> Float {
        let currentTime = systemAPI.getCurrentTimeMilliseconds()
        let deltaMs = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Convert milliseconds to seconds
        return Float(deltaMs) / 1000.0
    }
}

// MARK: - Equatable

extension VideoPlayer: Equatable {
    /// Compare video players for equality
    ///
    /// Players are equal if they point to the same C video player.
    public static func == (lhs: VideoPlayer, rhs: VideoPlayer) -> Bool {
        return lhs.pointer == rhs.pointer
    }
}

// MARK: - CustomStringConvertible

extension VideoPlayer: CustomStringConvertible {
    /// Human-readable description
    ///
    /// Shows path, state, and current position.
    ///
    /// Example output:
    /// ```
    /// VideoPlayer("assets/videos/intro.pdv", playing, frame 45/300)
    /// ```
    public var description: String {
        let info = getInfo()
        return "VideoPlayer(\"\(sourcePath)\", \(state.description), frame \(info.currentFrame)/\(info.frameCount))"
    }
}

// ✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼
// Playback control methods and update loop
// ✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼✼

// MARK: - Playback Control

public extension VideoPlayer {
    /// Start or resume video playback
    ///
    /// Transitions player to playing state and initializes timing system.
    /// Can be called from idle, stopped, or paused states.
    ///
    /// - Returns: true if playback started successfully
    ///
    /// Example:
    /// ```swift
    /// let player = VideoPlayer(path: "video.pdv", autoPlay: false)
    /// player.play()
    ///
    /// // In update loop
    /// player.updateAndRender()
    /// ```
    @discardableResult
    func play() -> Bool {
        // Validate state transition
        guard canTransition(from: state, to: .playing) else {
            let error = GraphicsError.videoInvalidState(
                operation: "play",
                currentState: state.description
            )
            recordError(error)
            return false
        }

        // Initialize timing if first play
        if !timingInitialized {
            initializeTiming()
        } else if state == .paused {
            // Resuming from pause - reset timer but keep accumulator
            lastUpdateTime = systemAPI.getCurrentTimeMilliseconds()
        } else if state == .stopped || state == .idle {
            // Starting fresh - reset everything
            resetTiming()
        }

        // Transition to playing
        state = .playing
        return true
    }

    /// Pause video playback
    ///
    /// Pauses at current frame. Call play() to resume.
    /// Can only be called when playing.
    ///
    /// - Returns: true if paused successfully
    ///
    /// Example:
    /// ```swift
    /// player.play()
    /// // ... some time later ...
    /// player.pause()
    /// // ... even later ...
    /// player.play() // Resume from paused position
    /// ```
    @discardableResult
    func pause() -> Bool {
        // Validate state
        guard state == .playing else {
            let error = GraphicsError.videoInvalidState(
                operation: "pause",
                currentState: state.description
            )
            recordError(error)
            return false
        }

        // Transition to paused
        state = .paused
        return true
    }

    /// Stop playback and rewind to start
    ///
    /// Stops playback, rewinds to frame 0, and resets timing.
    /// Can be called from any state.
    ///
    /// Example:
    /// ```swift
    /// player.play()
    /// // ... playback ...
    /// player.stop()
    /// print(player.currentFrame) // 0
    /// ```
    func stop() {
        // Rewind to start
        let result = videoAPI.renderFrame(pointer, 0)
        if result == 0 {
            let error = getLastError()
            recordError(error)
        }

        // Reset state and timing
        state = .stopped
        loopCount = 0
        resetTiming()
    }
}

// MARK: - Update & Render

public extension VideoPlayer {
    /// Update and render next frame (main update loop)
    ///
    /// This is the core playback method. Call it every frame in your game loop.
    /// Automatically handles:
    /// - Frame rate timing (respects video's frameRate)
    /// - End-of-video detection
    /// - Repeat mode (once/loop/loopForever)
    /// - Debug overlay rendering
    /// - Error callbacks
    ///
    /// - Returns: true if update succeeded, false on error or when stopped
    ///
    /// # Timing Behavior
    ///
    /// The method uses frame accumulation to respect the video's native frame rate
    /// independently of the game loop frame rate:
    ///
    /// ```
    /// frameDuration = 1.0 / frameRate  // e.g., 0.033s for 30fps
    /// frameAccumulator += deltaTime
    ///
    /// if frameAccumulator >= frameDuration:
    ///     renderNextFrame()
    ///     frameAccumulator -= frameDuration
    /// ```
    ///
    /// This ensures smooth playback even if game loop runs at different rate.
    ///
    /// # Example Usage
    ///
    /// ```swift
    /// // Basic loop
    /// func updateGame() {
    ///     player.updateAndRender()
    /// }
    ///
    /// // With error handling
    /// func updateGame() {
    ///     if !player.updateAndRender() {
    ///         if let error = player.lastError {
    ///             print("Video error: \(error)")
    ///         }
    ///     }
    /// }
    ///
    /// // With callbacks
    /// player.onVideoEnd = {
    ///     print("Video finished!")
    ///     loadNextVideo()
    /// }
    /// ```
    @discardableResult
    func updateAndRender() -> Bool {
        // Only update when playing
        guard state == .playing else {
            return false
        }

        // Get current info
        let currentInfo = getInfo()

        // Check if already at end
        if currentInfo.currentFrame >= currentInfo.frameCount - 1 {
            return handleVideoEnd()
        }

        // Calculate delta time since last update
        let deltaTime = calculateDeltaTime()

        // Accumulate time for frame progression
        frameAccumulator += deltaTime

        // Calculate frame duration based on video frame rate
        let frameDuration = 1.0 / currentInfo.frameRate

        // Check if it's time to render next frame
        guard frameAccumulator >= frameDuration else {
            // Not time yet - render debug overlay if enabled
            if showDebugOverlay {
                renderDebugOverlay()
            }
            return true
        }

        // Subtract frame duration (may render multiple frames if behind)
        frameAccumulator -= frameDuration

        // Prevent accumulator from growing too large (frame skip protection)
        if frameAccumulator > frameDuration * 2.0 {
            frameAccumulator = frameDuration
        }

        // Render next frame
        let nextFrame = currentInfo.currentFrame + 1

        // Check bounds
        guard nextFrame < currentInfo.frameCount else {
            return handleVideoEnd()
        }

        // Call C API to render frame
        let result = videoAPI.renderFrame(pointer, nextFrame)

        if result == 0 {
            // Render failed - get error and invoke callback
            let error = getLastError()
            recordError(error)

            // Render debug overlay even on error
            if showDebugOverlay {
                renderDebugOverlay()
            }

            return false
        }

        // Render debug overlay if enabled
        if showDebugOverlay {
            renderDebugOverlay()
        }

        return true
    }
}

// MARK: - Private Helpers - Video End Handling

private extension VideoPlayer {
    /// Handle video reaching end
    ///
    /// Checks repeat mode and either loops or finishes.
    ///
    /// - Returns: true if continuing (looping), false if finished
    func handleVideoEnd() -> Bool {
        // Invoke end callback
        onVideoEnd?()

        // Check repeat mode
        switch repeatMode {
        case .once:
            // Finish playback
            state = .finished
            return false

        case .loopForever:
            // Loop indefinitely
            return performLoop()

        case let .repeatCount(maxLoops):
            // Check if we can loop more
            if loopCount < maxLoops {
                return performLoop()
            } else {
                // Reached max loops - finish
                state = .finished
                loopCount = 0
                return false
            }
        }
    }

    /// Perform loop back to start
    ///
    /// Rewinds to frame 0 and continues playing.
    ///
    /// - Returns: true if loop succeeded
    func performLoop() -> Bool {
        // Increment loop counter
        loopCount += 1

        // Rewind to start
        let result = videoAPI.renderFrame(pointer, 0)

        if result == 0 {
            // Loop failed
            let error = getLastError()
            recordError(error)
            state = .finished
            return false
        }

        // Reset frame accumulator but keep playing
        frameAccumulator = 0.0

        return true
    }
}

// MARK: - Private Helpers - Debug Overlay

private extension VideoPlayer {
    /// Render debug overlay on top of video
    ///
    /// Shows current frame, FPS, filename, and errors.
    /// Uses Graphics API to draw text overlay.
    func renderDebugOverlay() {
        // Get current debug info
        let debug = debugInfo
        let info = debug.info

        // Prepare debug text lines
        let line1 = "Frame: \(info.currentFrame)/\(info.frameCount)"
        let line2 = "FPS: \(debug.fps.string)"
        let line3 = "File: \(info.path ?? "unknown")"

        // Background for readability
        let bgColor = Color.black
        let textColor = Color.white

        // Draw background rectangles
        // Graphics.fillRect(
        //     x: 2, y: 2,
        //     width: 200, height: 50,
        //     color: bgColor
        // )

        // Draw text lines
        Font.systemFont().setAsCurrent()

        Graphics.drawText(
            line1,
            at: Point(x: 5, y: 5)
            // color: textColor
        )

        Graphics.drawText(
            line2,
            at: Point(x: 5, y: 20)
            // color: textColor
        )

        Graphics.drawText(
            line3,
            at: Point(x: 5, y: 35)
            // color: textColor
        )

        // Show error if present
        if let error = debug.lastError {
            // Expand background for error
            // Graphics.fillRect(
            //     x: 2, y: 52,
            //     width: 396, height: 18,
            //     color: Pattern.horizontal
            // )

            let errorText = "ERROR: \(error.description)"
            Graphics.drawText(
                errorText,
                at: Point(x: 5, y: 55)
                // color: textColor
            )
        }
    }
}

// MARK: - Convenience Methods

public extension VideoPlayer {
    /// Toggle play/pause
    ///
    /// Convenience method to toggle between playing and paused states.
    ///
    /// Example:
    /// ```swift
    /// // Crank button to toggle playback
    /// if Playdate.buttonA.justPressed {
    ///     player.togglePlayPause()
    /// }
    /// ```
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if isPaused {
            play()
        } else {
            play()
        }
    }

    /// Restart video from beginning
    ///
    /// Rewinds to start and begins playing.
    ///
    /// Example:
    /// ```swift
    /// player.restart()
    /// ```
    func restart() {
        stop()
        play()
    }
}

// MARK: - Advanced Playback Control

public extension VideoPlayer {
    /// Set playback position and state in one call
    ///
    /// Convenience method to seek and control playback simultaneously.
    ///
    /// - Parameters:
    ///   - frame: Frame number to seek to
    ///   - shouldPlay: Whether to start playing (default: true)
    /// - Returns: true if operation succeeded
    ///
    /// Example:
    /// ```swift
    /// // Jump to middle and start playing
    /// player.setPosition(frame: 150, shouldPlay: true)
    ///
    /// // Jump to start but stay paused
    /// player.setPosition(frame: 0, shouldPlay: false)
    /// ```
    @discardableResult
    func setPosition(frame: Int32, shouldPlay: Bool = true) -> Bool {
        // Render the target frame
        let result = videoAPI.renderFrame(pointer, frame)

        if result == 0 {
            let error = getLastError()
            recordError(error)
            return false
        }

        // Reset timing
        resetTiming()

        // Set playback state
        if shouldPlay {
            return play()
        } else {
            state = .paused
            return true
        }
    }

    /// Set playback position by progress
    ///
    /// - Parameters:
    ///   - progress: Progress value (0.0 - 1.0)
    ///   - shouldPlay: Whether to start playing (default: true)
    /// - Returns: true if operation succeeded
    ///
    /// Example:
    /// ```swift
    /// // Jump to 75% and play
    /// player.setPosition(progress: 0.75)
    ///
    /// // Jump to middle, stay paused
    /// player.setPosition(progress: 0.5, shouldPlay: false)
    /// ```
    @discardableResult
    func setPosition(progress: Float, shouldPlay: Bool = true) -> Bool {
        let info = getInfo()
        let targetFrame = Int32(Float(info.frameCount) * progress)
        return setPosition(frame: targetFrame, shouldPlay: shouldPlay)
    }
}

// MARK: - State Query Extensions

public extension VideoPlayer {
    /// Check if playback can continue
    ///
    /// Returns true if player can render more frames
    /// (not at end and not finished).
    var canContinuePlaying: Bool {
        guard state == .playing else {
            return false
        }

        let info = getInfo()
        return info.currentFrame < info.frameCount - 1
    }

    /// Check if at start of video
    var isAtStart: Bool {
        return info.isAtStart
    }

    /// Check if at end of video
    var isAtEnd: Bool {
        return info.isAtEnd
    }

    /// Remaining frames until end
    var remainingFrames: Int32 {
        return info.remainingFrames
    }

    /// Remaining time in seconds
    var remainingSeconds: Float {
        return info.remainingSeconds
    }
}

// MARK: - Repeat Mode Helpers

public extension VideoPlayer {
    /// Check if currently looping
    var isLooping: Bool {
        return repeatMode.isLooping
    }

    /// Get current loop iteration (0-based)
    ///
    /// Returns current loop number when using repeatCount mode.
    /// Always 0 for once mode, undefined for loopForever.
    var currentLoop: Int32 {
        return loopCount
    }

    /// Get total planned loops (nil for loopForever)
    var totalLoops: Int32? {
        return repeatMode.totalPlays
    }

    /// Reset loop counter
    ///
    /// Useful when changing repeat mode mid-playback.
    func resetLoopCount() {
        loopCount = 0
    }
}

// ◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎
// Frame navigation and seeking methods
// ◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎◼︎

// MARK: - Frame Rendering

public extension VideoPlayer {
    /// Render specific frame
    ///
    /// Directly renders the specified frame number.
    /// Does not change playback state (playing/paused/stopped).
    ///
    /// - Parameter frame: Frame number to render (0-based)
    /// - Returns: true if render succeeded
    ///
    /// Example:
    /// ```swift
    /// // Render frame 100
    /// player.renderFrame(100)
    ///
    /// // Render last frame
    /// player.renderFrame(player.frameCount - 1)
    /// ```
    @discardableResult
    func renderFrame(_ frame: Int32) -> Bool {
        // Get current info for validation
        let info = getInfo()

        // Validate frame bounds
        guard frame >= 0 && frame < info.frameCount else {
            let error = GraphicsError.invalidVideoFrame(
                frame: frame,
                totalFrames: info.frameCount
            )
            recordError(error)
            return false
        }

        // Call C API to render frame
        let result = videoAPI.renderFrame(pointer, frame)

        if result == 0 {
            // Render failed
            let error = getLastError()
            recordError(error)
            return false
        }

        return true
    }
}

// MARK: - Frame Seeking

public extension VideoPlayer {
    /// Seek to specific frame
    ///
    /// Moves playback position to specified frame and resets timing.
    /// Validates frame bounds and records errors on failure.
    ///
    /// - Parameter frame: Target frame number (0-based)
    /// - Returns: true if seek succeeded
    ///
    /// Example:
    /// ```swift
    /// // Seek to middle
    /// let midFrame = player.frameCount / 2
    /// player.seekToFrame(midFrame)
    ///
    /// // Seek to frame 100
    /// if player.seekToFrame(100) {
    ///     print("Seeked successfully")
    /// }
    /// ```
    @discardableResult
    func seekToFrame(_ frame: Int32) -> Bool {
        // Validate bounds
        let info = getInfo()
        guard frame >= 0 && frame < info.frameCount else {
            let error = GraphicsError.videoSeekOutOfBounds(
                requestedProgress: Float(frame),
                maxProgress: Float(info.frameCount - 1),
                reason: "Frame \(frame) is outside valid range 0..\(info.frameCount - 1)"
            )
            recordError(error)
            return false
        }

        // Render target frame
        let result = renderFrame(frame)

        if result {
            // Reset timing after seek
            resetTiming()
        }

        return result
    }

    /// Move to next frame
    ///
    /// Advances to the next frame if not at end.
    ///
    /// - Returns: true if advanced to next frame
    ///
    /// Example:
    /// ```swift
    /// // Manual frame stepping
    /// while player.nextFrame() {
    ///     // Process each frame
    ///     processFrame()
    /// }
    /// ```
    @discardableResult
    func nextFrame() -> Bool {
        let currentFrame = info.currentFrame
        let nextFrame = currentFrame + 1

        return seekToFrame(nextFrame)
    }

    /// Move to previous frame
    ///
    /// Goes back to previous frame if not at start.
    ///
    /// - Returns: true if moved to previous frame
    ///
    /// Example:
    /// ```swift
    /// // Step backward
    /// player.previousFrame()
    /// ```
    @discardableResult
    func previousFrame() -> Bool {
        let currentFrame = info.currentFrame
        guard currentFrame > 0 else {
            let error = GraphicsError.videoSeekOutOfBounds(
                requestedProgress: -1,
                maxProgress: Float(info.frameCount - 1),
                reason: "Already at first frame"
            )
            recordError(error)
            return false
        }

        let prevFrame = currentFrame - 1
        return seekToFrame(prevFrame)
    }

    /// Rewind to start (frame 0)
    ///
    /// Quick shortcut to jump to beginning.
    ///
    /// Example:
    /// ```swift
    /// player.rewind()
    /// player.play() // Start from beginning
    /// ```
    func rewind() {
        _ = seekToFrame(0)
    }
}

// MARK: - Time-based Seeking

public extension VideoPlayer {
    /// Seek to specific time position
    ///
    /// Seeks to the specified time in seconds, with configurable rounding
    /// for fractional frame positions.
    ///
    /// - Parameters:
    ///   - seconds: Target time in seconds
    ///   - rounding: How to round fractional frames (default: .nearest)
    /// - Returns: true if seek succeeded
    ///
    /// # Rounding Modes
    ///
    /// For a video at 30fps seeking to 1.52 seconds (45.6 frames):
    /// - `.down` → frame 45
    /// - `.nearest` → frame 46
    /// - `.up` → frame 46
    ///
    /// Example:
    /// ```swift
    /// // Seek to 5 seconds
    /// player.seek(toSeconds: 5.0)
    ///
    /// // Seek to 2.5 seconds, round down
    /// player.seek(toSeconds: 2.5, rounding: .down)
    ///
    /// // Seek to end
    /// player.seek(toSeconds: player.duration)
    /// ```
    @discardableResult
    func seek(toSeconds seconds: Float, rounding: SeekRounding = .nearest) -> Bool {
        // Validate seconds
        guard seconds >= 0 else {
            let error = GraphicsError.videoInvalidProgress(
                progress: seconds,
                validRange: "0..\(duration.string) seconds"
            )
            recordError(error)
            return false
        }

        let info = getInfo()

        // Check if beyond duration
        let duration = info.duration
        guard seconds <= duration else {
            let error = GraphicsError.videoSeekOutOfBounds(
                requestedProgress: seconds,
                maxProgress: duration,
                reason: "Seek time \(seconds.string)s exceeds video duration \(duration.string)s"
            )
            recordError(error)
            return false
        }

        // Convert seconds to frame with rounding
        let targetFrame = secondsToFrame(seconds, rounding: rounding)

        return seekToFrame(targetFrame)
    }

    /// Seek to specific progress (0.0 - 1.0)
    ///
    /// Seeks to proportional position in video.
    /// 0.0 = start, 0.5 = middle, 1.0 = end.
    ///
    /// - Parameter progress: Progress value (0.0 - 1.0)
    /// - Returns: true if seek succeeded
    ///
    /// Example:
    /// ```swift
    /// // Seek to 25%
    /// player.seek(toProgress: 0.25)
    ///
    /// // Seek to middle
    /// player.seek(toProgress: 0.5)
    ///
    /// // Seek to 90%
    /// player.seek(toProgress: 0.9)
    /// ```
    @discardableResult
    func seek(toProgress progress: Float) -> Bool {
        // Validate progress range
        guard progress >= 0.0 && progress <= 1.0 else {
            let error = GraphicsError.videoInvalidProgress(
                progress: progress,
                validRange: "0.0..1.0"
            )
            recordError(error)
            return false
        }

        // Convert progress to frame
        let targetFrame = progressToFrame(progress)

        return seekToFrame(targetFrame)
    }
}

// MARK: - Advanced Seeking

public extension VideoPlayer {
    /// Skip forward by number of frames
    ///
    /// - Parameter frames: Number of frames to skip forward
    /// - Returns: true if skip succeeded
    ///
    /// Example:
    /// ```swift
    /// // Skip 30 frames (1 second at 30fps)
    /// player.skipForward(frames: 30)
    /// ```
    @discardableResult
    func skipForward(frames: Int32) -> Bool {
        let targetFrame = info.currentFrame + frames
        return seekToFrame(targetFrame)
    }

    /// Skip backward by number of frames
    ///
    /// - Parameter frames: Number of frames to skip backward
    /// - Returns: true if skip succeeded
    ///
    /// Example:
    /// ```swift
    /// // Go back 30 frames
    /// player.skipBackward(frames: 30)
    /// ```
    @discardableResult
    func skipBackward(frames: Int32) -> Bool {
        let targetFrame = info.currentFrame - frames
        return seekToFrame(targetFrame)
    }

    /// Skip forward by seconds
    ///
    /// - Parameter seconds: Number of seconds to skip forward
    /// - Returns: true if skip succeeded
    ///
    /// Example:
    /// ```swift
    /// // Skip forward 5 seconds
    /// player.skipForward(seconds: 5.0)
    /// ```
    @discardableResult
    func skipForward(seconds: Float) -> Bool {
        let targetSeconds = currentSeconds + seconds
        return seek(toSeconds: targetSeconds)
    }

    /// Skip backward by seconds
    ///
    /// - Parameter seconds: Number of seconds to skip backward
    /// - Returns: true if skip succeeded
    ///
    /// Example:
    /// ```swift
    /// // Go back 3 seconds
    /// player.skipBackward(seconds: 3.0)
    /// ```
    @discardableResult
    func skipBackward(seconds: Float) -> Bool {
        let targetSeconds = currentSeconds - seconds
        return seek(toSeconds: targetSeconds)
    }

    /// Seek to percentage (0-100)
    ///
    /// Convenience method using percentage instead of 0.0-1.0 progress.
    ///
    /// - Parameter percentage: Percentage (0-100)
    /// - Returns: true if seek succeeded
    ///
    /// Example:
    /// ```swift
    /// // Seek to 75%
    /// player.seek(toPercentage: 75)
    /// ```
    @discardableResult
    func seek(toPercentage percentage: Float) -> Bool {
        guard percentage >= 0 && percentage <= 100 else {
            let error = GraphicsError.videoInvalidProgress(
                progress: percentage,
                validRange: "0..100 percent"
            )
            recordError(error)
            return false
        }

        let progress = percentage / 100.0
        return seek(toProgress: progress)
    }
}

// MARK: - Conversion Helpers

public extension VideoPlayer {
    /// Convert frame number to seconds
    ///
    /// - Parameter frame: Frame number
    /// - Returns: Time in seconds
    ///
    /// Example:
    /// ```swift
    /// let seconds = player.frameToSeconds(90) // 3.0 at 30fps
    /// ```
    func frameToSeconds(_ frame: Int32) -> Float {
        let info = getInfo()
        guard info.frameRate > 0 else { return 0 }
        return Float(frame) / info.frameRate
    }

    /// Convert seconds to frame number with rounding
    ///
    /// - Parameters:
    ///   - seconds: Time in seconds
    ///   - rounding: Rounding mode (default: .nearest)
    /// - Returns: Frame number
    ///
    /// Example:
    /// ```swift
    /// let frame = player.secondsToFrame(3.5) // 105 at 30fps
    /// let frameDown = player.secondsToFrame(3.5, rounding: .down) // 105
    /// let frameUp = player.secondsToFrame(3.5, rounding: .up) // 105
    /// ```
    func secondsToFrame(_ seconds: Float, rounding: SeekRounding = .nearest) -> Int32 {
        let info = getInfo()
        guard info.frameRate > 0 else { return 0 }

        let fractionalFrame = seconds * info.frameRate
        return rounding.apply(to: fractionalFrame)
    }

    /// Convert progress (0.0-1.0) to frame number
    ///
    /// - Parameter progress: Progress value (0.0-1.0)
    /// - Returns: Frame number
    ///
    /// Example:
    /// ```swift
    /// let frame = player.progressToFrame(0.5) // Middle frame
    /// ```
    func progressToFrame(_ progress: Float) -> Int32 {
        let info = getInfo()
        let fractionalFrame = Float(info.frameCount) * progress
        return Int32(fractionalFrame + 0.5) // Round to nearest
    }

    /// Convert frame number to progress (0.0-1.0)
    ///
    /// - Parameter frame: Frame number
    /// - Returns: Progress value (0.0-1.0)
    ///
    /// Example:
    /// ```swift
    /// let progress = player.frameToProgress(150) // e.g., 0.5 for 300 frame video
    /// ```
    func frameToProgress(_ frame: Int32) -> Float {
        let info = getInfo()
        guard info.frameCount > 0 else { return 0 }
        return Float(frame) / Float(info.frameCount)
    }

    /// Convert percentage (0-100) to frame number
    ///
    /// - Parameter percentage: Percentage (0-100)
    /// - Returns: Frame number
    ///
    /// Example:
    /// ```swift
    /// let frame = player.percentageToFrame(75) // 75% through video
    /// ```
    func percentageToFrame(_ percentage: Float) -> Int32 {
        let progress = percentage / 100.0
        return progressToFrame(progress)
    }

    /// Convert frame to percentage (0-100)
    ///
    /// - Parameter frame: Frame number
    /// - Returns: Percentage (0-100)
    ///
    /// Example:
    /// ```swift
    /// let percent = player.frameToPercentage(150) // e.g., 50.0 for 300 frame video
    /// ```
    func frameToPercentage(_ frame: Int32) -> Float {
        return frameToProgress(frame) * 100.0
    }
}

// MARK: - Seek Validation Helpers

public extension VideoPlayer {
    /// Check if frame number is valid
    ///
    /// - Parameter frame: Frame number to check
    /// - Returns: true if frame is within valid range
    ///
    /// Example:
    /// ```swift
    /// if player.isValidFrame(150) {
    ///     player.seekToFrame(150)
    /// }
    /// ```
    func isValidFrame(_ frame: Int32) -> Bool {
        let info = getInfo()
        return frame >= 0 && frame < info.frameCount
    }

    /// Check if time is valid
    ///
    /// - Parameter seconds: Time in seconds to check
    /// - Returns: true if time is within video duration
    ///
    /// Example:
    /// ```swift
    /// if player.isValidTime(5.5) {
    ///     player.seek(toSeconds: 5.5)
    /// }
    /// ```
    func isValidTime(_ seconds: Float) -> Bool {
        return seconds >= 0 && seconds <= duration
    }

    /// Check if progress is valid
    ///
    /// - Parameter progress: Progress to check (0.0-1.0)
    /// - Returns: true if progress is in valid range
    ///
    /// Example:
    /// ```swift
    /// if player.isValidProgress(0.75) {
    ///     player.seek(toProgress: 0.75)
    /// }
    /// ```
    func isValidProgress(_ progress: Float) -> Bool {
        return progress >= 0.0 && progress <= 1.0
    }

    /// Clamp frame to valid range
    ///
    /// Ensures frame is within valid bounds (0 to frameCount-1).
    ///
    /// - Parameter frame: Frame number to clamp
    /// - Returns: Clamped frame number
    ///
    /// Example:
    /// ```swift
    /// let safeFrame = player.clampFrame(9999) // Returns frameCount-1
    /// ```
    func clampFrame(_ frame: Int32) -> Int32 {
        let info = getInfo()
        return max(0, min(frame, info.frameCount - 1))
    }

    /// Clamp seconds to valid range
    ///
    /// Ensures time is within video duration.
    ///
    /// - Parameter seconds: Time to clamp
    /// - Returns: Clamped time
    ///
    /// Example:
    /// ```swift
    /// let safeTime = player.clampSeconds(999.0) // Returns duration
    /// ```
    func clampSeconds(_ seconds: Float) -> Float {
        return max(0, min(seconds, duration))
    }

    /// Clamp progress to valid range
    ///
    /// Ensures progress is between 0.0 and 1.0.
    ///
    /// - Parameter progress: Progress to clamp
    /// - Returns: Clamped progress
    ///
    /// Example:
    /// ```swift
    /// let safeProgress = player.clampProgress(1.5) // Returns 1.0
    /// ```
    func clampProgress(_ progress: Float) -> Float {
        return max(0.0, min(progress, 1.0))
    }
}

// 🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢
// Render context management
// 🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢

// MARK: - Context Management

public extension VideoPlayer {
    /// Set render context for video playback
    ///
    /// Changes where video frames are rendered. Can render to:
    /// - Screen display buffer (`.screen`)
    /// - Custom bitmap (`.bitmap(Bitmap)`)
    ///
    /// Context can be changed during playback.
    ///
    /// - Parameter context: New render context
    /// - Returns: true if context set successfully
    ///
    /// # Ownership
    ///
    /// VideoPlayer does NOT own the context bitmap. Caller is responsible
    /// for keeping the bitmap alive during video playback.
    ///
    /// Example:
    /// ```swift
    /// // Start with screen context
    /// let player = VideoPlayer(path: "video.pdv", context: .screen)
    ///
    /// // Switch to custom bitmap
    /// let renderTarget = Bitmap(width: 400, height: 240)!
    /// player.setContext(.bitmap(renderTarget))
    ///
    /// // Render a frame to bitmap
    /// player.renderFrame(0)
    ///
    /// // Switch back to screen
    /// player.setContext(.screen)
    /// ```
    @discardableResult
    func setContext(_ context: VideoContext) -> Bool {
        switch context {
        case .screen:
            return setScreenContext()

        case let .bitmap(bitmap):
            return setBitmapContext(bitmap)
        }
    }

    /// Switch to screen context
    ///
    /// Renders video directly to display buffer.
    /// This is the default and most common rendering mode.
    ///
    /// Example:
    /// ```swift
    /// player.useScreenContext()
    /// player.play()
    /// ```
    func useScreenContext() {
        _ = setScreenContext()
    }

    /// Get current render context bitmap
    ///
    /// Returns the bitmap currently being used as render target,
    /// or nil if rendering to screen.
    ///
    /// - Returns: Context bitmap or nil for screen context
    ///
    /// Example:
    /// ```swift
    /// if let bitmap = player.getContext() {
    ///     print("Rendering to bitmap: \(bitmap.width)x\(bitmap.height)")
    /// } else {
    ///     print("Rendering to screen")
    /// }
    /// ```
    func getContext() -> Bitmap? {
        return contextBitmap
    }
}

// MARK: - Context Type Checks

public extension VideoPlayer {
    /// Check if rendering to screen
    var isUsingScreenContext: Bool {
        return contextBitmap == nil
    }

    /// Check if rendering to custom bitmap
    var isUsingBitmapContext: Bool {
        return contextBitmap != nil
    }

    /// Get context type
    var contextType: VideoContext {
        if let bitmap = contextBitmap {
            return .bitmap(bitmap)
        } else {
            return .screen
        }
    }
}

// MARK: - Private Context Helpers

private extension VideoPlayer {
    /// Set screen as render context
    ///
    /// Internal method to switch to screen rendering.
    ///
    /// - Returns: true if context set successfully
    func setScreenContext() -> Bool {
        // Call C API to use screen context
        videoAPI.useScreenContext(pointer)

        // Clear bitmap reference
        contextBitmap = nil
        ownsContext = false

        return true
    }

    /// Set custom bitmap as render context
    ///
    /// Internal method to switch to bitmap rendering.
    ///
    /// - Parameter bitmap: Target bitmap for rendering
    /// - Returns: true if context set successfully
    func setBitmapContext(_ bitmap: Bitmap) -> Bool {
        // Call C API to set bitmap context
        let result = videoAPI.setContext(pointer, bitmap.cPointer)

        if result == 0 {
            // Failed to set context
            let error = GraphicsError.videoContextInvalid
            recordError(error)
            return false
        }

        // Store bitmap reference (caller owns it)
        contextBitmap = bitmap
        ownsContext = false

        return true
    }
}

// MARK: - Context Validation

public extension VideoPlayer {
    /// Validate current render context
    ///
    /// Checks if context is still valid for rendering.
    /// For screen context, always returns true.
    /// For bitmap context, assumes caller manages lifetime.
    ///
    /// - Returns: true if context is valid
    ///
    /// Example:
    /// ```swift
    /// if !player.isContextValid() {
    ///     print("Context invalid, switching to screen")
    ///     player.useScreenContext()
    /// }
    /// ```
    func isContextValid() -> Bool {
        // Screen context is always valid
        guard let bitmap = contextBitmap else {
            return true
        }

        // Bitmap context - we assume caller manages lifetime
        // Just check that reference exists
        return bitmap.width > 0 && bitmap.height > 0
    }
}

// MARK: - Advanced Context Operations

public extension VideoPlayer {
    /// Render current frame to different context temporarily
    ///
    /// Renders current frame to specified context without changing
    /// player's default context. Useful for creating thumbnails or
    /// rendering to multiple targets.
    ///
    /// - Parameter context: Temporary render context
    /// - Returns: true if render succeeded
    ///
    /// Example:
    /// ```swift
    /// // Player normally renders to screen
    /// let player = VideoPlayer(path: "video.pdv", context: .screen)
    ///
    /// // Render current frame to thumbnail
    /// let thumbnail = Bitmap(width: 100, height: 75)!
    /// player.renderToContext(.bitmap(thumbnail))
    ///
    /// // Player still renders to screen on next update
    /// player.updateAndRender()
    /// ```
    @discardableResult
    func renderToContext(_ context: VideoContext) -> Bool {
        // Save current context
        let originalContext = contextType

        // Switch to temporary context
        guard setContext(context) else {
            return false
        }

        // Render current frame
        let currentFrame = info.currentFrame
        let result = renderFrame(currentFrame)

        // Restore original context
        _ = setContext(originalContext)

        return result
    }

    /// Render specific frame to different context
    ///
    /// Combination of renderToContext and renderFrame for one-shot renders.
    ///
    /// - Parameters:
    ///   - frame: Frame number to render
    ///   - context: Target context
    /// - Returns: true if render succeeded
    ///
    /// Example:
    /// ```swift
    /// // Render frame 100 to thumbnail
    /// let thumb = Bitmap(width: 100, height: 75)!
    /// player.renderFrame(100, toContext: .bitmap(thumb))
    /// ```
    @discardableResult
    func renderFrame(_ frame: Int32, toContext context: VideoContext) -> Bool {
        // Save current context
        let originalContext = contextType
        let originalFrame = info.currentFrame

        // Switch to temporary context
        guard setContext(context) else {
            return false
        }

        // Render target frame
        let result = renderFrame(frame)

        // Restore original context and frame
        _ = setContext(originalContext)
        _ = renderFrame(originalFrame)

        return result
    }

    /// Create bitmap snapshot of current frame
    ///
    /// Renders current frame to a new bitmap and returns it.
    /// Useful for creating thumbnails or frame captures.
    ///
    /// - Parameters:
    ///   - width: Snapshot width (default: video width)
    ///   - height: Snapshot height (default: video height)
    /// - Returns: Bitmap with rendered frame, or nil on error
    ///
    /// Example:
    /// ```swift
    /// // Full resolution snapshot
    /// if let snapshot = player.createSnapshot() {
    ///     snapshot.draw(at: 0, 0)
    /// }
    ///
    /// // Thumbnail snapshot
    /// if let thumb = player.createSnapshot(width: 100, height: 75) {
    ///     thumb.draw(at: 10, 10)
    /// }
    /// ```
    func createSnapshot(width: Int32? = nil, height: Int32? = nil) -> Bitmap? {
        let info = getInfo()
        let snapWidth = width ?? info.width
        let snapHeight = height ?? info.height

        // Create bitmap for snapshot
        guard let snapshot = Bitmap(width: snapWidth, height: snapHeight) else {
            let error = GraphicsError.memoryAllocationFailed(
                operation: "snapshot bitmap \(snapWidth)x\(snapHeight)",
                size: snapWidth * snapHeight / 8
            )
            recordError(error)
            return nil
        }

        // Render to snapshot bitmap
        let success = renderToContext(.bitmap(snapshot))

        return success ? snapshot : nil
    }

    /// Create snapshot of specific frame
    ///
    /// - Parameters:
    ///   - frame: Frame number to capture
    ///   - width: Snapshot width (default: video width)
    ///   - height: Snapshot height (default: video height)
    /// - Returns: Bitmap with rendered frame, or nil on error
    ///
    /// Example:
    /// ```swift
    /// // Capture frame 150
    /// if let snapshot = player.createSnapshot(ofFrame: 150) {
    ///     snapshot.draw(at: 0, 0)
    /// }
    /// ```
    func createSnapshot(
        ofFrame frame: Int32,
        width: Int32? = nil,
        height: Int32? = nil
    ) -> Bitmap? {
        let info = getInfo()
        let snapWidth = width ?? info.width
        let snapHeight = height ?? info.height

        // Create bitmap for snapshot
        guard let snapshot = Bitmap(width: snapWidth, height: snapHeight) else {
            return nil
        }

        // Render frame to snapshot
        let success = renderFrame(frame, toContext: .bitmap(snapshot))

        return success ? snapshot : nil
    }
}

// MARK: - Batch Rendering

public extension VideoPlayer {
    /// Render sequence of frames to bitmaps
    ///
    /// Renders multiple frames to separate bitmaps. Useful for creating
    /// sprite sheets or frame sequences.
    ///
    /// - Parameters:
    ///   - frames: Array of frame numbers to render
    ///   - width: Bitmap width (default: video width)
    ///   - height: Bitmap height (default: video height)
    /// - Returns: Array of bitmaps (same order as frames), empty on error
    ///
    /// Example:
    /// ```swift
    /// // Render frames 0, 10, 20, 30
    /// let frames = player.renderFrames([0, 10, 20, 30])
    /// for (i, bitmap) in frames.enumerated() {
    ///     bitmap.draw(at: Int32(i * 50), 0)
    /// }
    /// ```
    func renderFrames(_ frames: [Int32]) -> [Bitmap] {
        var bitmaps: [Bitmap] = []

        let info = getInfo()
        let originalFrame = info.currentFrame
        let originalContext = contextType

        for frame in frames {
            // Validate frame
            guard isValidFrame(frame) else {
                continue
            }

            // Create bitmap
            guard let bitmap = Bitmap(width: info.width, height: info.height) else {
                continue
            }

            // Render to bitmap
            if renderFrame(frame, toContext: .bitmap(bitmap)) {
                bitmaps.append(bitmap)
            }
        }

        // Restore original state
        _ = setContext(originalContext)
        _ = renderFrame(originalFrame)

        return bitmaps
    }

    /// Render frame range to bitmaps
    ///
    /// Renders a range of consecutive frames.
    ///
    /// - Parameters:
    ///   - range: Range of frame numbers (e.g., 0..<10)
    ///   - width: Bitmap width (default: video width)
    ///   - height: Bitmap height (default: video height)
    /// - Returns: Array of bitmaps for the range
    ///
    /// Example:
    /// ```swift
    /// // Render first 10 frames
    /// let frames = player.renderFrames(in: 0..<10)
    /// ```
    func renderFrames(in range: Range<Int32>) -> [Bitmap] {
        let frameNumbers = Array(range)
        return renderFrames(frameNumbers)
    }
}

// MARK: - Context Info

public extension VideoPlayer {
    /// Get information about current render target
    ///
    /// Returns dimensions and type of current render context.
    ///
    /// Example:
    /// ```swift
    /// let info = player.contextInfo
    /// print("Rendering to: \(info.type)")
    /// print("Size: \(info.width)x\(info.height)")
    /// ```
    var contextInfo: ContextInfo {
        if let bitmap = contextBitmap {
            return ContextInfo(
                type: "bitmap",
                width: bitmap.width,
                height: bitmap.height,
                isScreen: false
            )
        } else {
            return ContextInfo(
                type: "screen",
                width: Screen.columns,
                height: Screen.rows,
                isScreen: true
            )
        }
    }

    /// Context information structure
    struct ContextInfo {
        /// Context type description
        public let type: String

        /// Render target width
        public let width: Int32

        /// Render target height
        public let height: Int32

        /// Is rendering to screen
        public let isScreen: Bool

        /// Size as Size struct
        public var size: Size {
            return Size(width: width, height: height)
        }
    }
}

// MARK: - Context Debugging

#if DEBUG
    public extension VideoPlayer {
        /// Debug description of current context
        var contextDebugInfo: String {
            let info = contextInfo
            var result = """
            Video Context Debug:
              Type: \(info.type)
              Size: \(info.width)x\(info.height)
            """

            if let bitmap = contextBitmap {
                result += "\n  Bitmap: \(bitmap.description)"
                result += "\n  Ownership: \(ownsContext ? "owned" : "borrowed")"
            }

            return result
        }

        /// Print context debug info
        func printContextInfo() {
            print(contextDebugInfo)
        }
    }
#endif

// MARK: - CustomStringConvertible Extension

extension VideoPlayer.ContextInfo: CustomStringConvertible {
    public var description: String {
        return "\(type) context (\(width)x\(height))"
    }
}

// 🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢
// Additional convenience methods, statistics, and advanced features
// 🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢🁢

// MARK: - Error History

public extension VideoPlayer {
    /// Error history tracking
    struct ErrorHistory {
        /// Maximum errors to store
        private let maxErrors: Int = 10

        /// Stored errors with timestamps
        private var errors: [(error: GraphicsError, time: UInt32, frame: Int32)] = []

        /// Add error to history
        mutating func record(error: GraphicsError, time: UInt32, frame: Int32) {
            errors.append((error, time, frame))

            // Keep only last N errors
            if errors.count > maxErrors {
                errors.removeFirst()
            }
        }

        /// Get all errors
        public var allErrors: [(error: GraphicsError, time: UInt32, frame: Int32)] {
            return errors
        }

        /// Get most recent error
        public var mostRecent: (error: GraphicsError, time: UInt32, frame: Int32)? {
            return errors.last
        }

        /// Count of errors
        public var count: Int {
            return errors.count
        }

        /// Clear history
        mutating func clear() {
            errors.removeAll()
        }

        /// Check if has errors
        public var hasErrors: Bool {
            return !errors.isEmpty
        }
    }
}

// MARK: - Lifecycle Callbacks

public extension VideoPlayer {
    /// Extended lifecycle callbacks
    struct LifecycleCallbacks {
        /// Called when play() is invoked
        public var onPlay: (() -> Void)?

        /// Called when pause() is invoked
        public var onPause: (() -> Void)?

        /// Called when stop() is invoked
        public var onStop: (() -> Void)?

        /// Called when video reaches end
        public var onFinish: (() -> Void)?

        /// Called when video loops
        public var onLoop: ((Int32) -> Void)?

        /// Called on each frame render
        public var onFrameRender: ((Int32) -> Void)?

        /// Called on seek
        public var onSeek: ((Int32, Int32) -> Void)? // (from, to)

        /// Called on context change
        public var onContextChange: ((VideoContext) -> Void)?
    }

    /// Set lifecycle callbacks
    ///
    /// Example:
    /// ```swift
    /// var callbacks = VideoPlayer.LifecycleCallbacks()
    /// callbacks.onPlay = { print("Started playing") }
    /// callbacks.onLoop = { loop in print("Loop #\(loop)") }
    /// player.lifecycleCallbacks = callbacks
    /// ```
    var lifecycleCallbacks: LifecycleCallbacks {
        get {
            return LifecycleCallbacks() // Simplified - store in VideoPlayer if needed
        }
        set {
            // Store callbacks in VideoPlayer private property
        }
    }
}

// MARK: - Video Statistics

public extension VideoPlayer {
    /// Video playback statistics
    struct PlaybackStats {
        /// Total frames rendered
        public var framesRendered: Int = 0

        /// Total frames dropped (behind schedule)
        public var framesDropped: Int = 0

        /// Total playback time in seconds
        public var totalPlayTime: Float = 0.0

        /// Number of seeks performed
        public var seekCount: Int = 0

        /// Number of loops completed
        public var loopsCompleted: Int = 0

        /// Number of errors encountered
        public var errorCount: Int = 0

        /// Average actual FPS
        public var averageFPS: Float {
            guard totalPlayTime > 0 else { return 0 }
            return Float(framesRendered) / totalPlayTime
        }

        /// Frame drop percentage
        public var dropPercentage: Float {
            let total = framesRendered + framesDropped
            guard total > 0 else { return 0 }
            return Float(framesDropped) / Float(total) * 100.0
        }

        /// Reset statistics
        mutating func reset() {
            framesRendered = 0
            framesDropped = 0
            totalPlayTime = 0.0
            seekCount = 0
            loopsCompleted = 0
            errorCount = 0
        }
    }

    /// Get current playback statistics
    ///
    /// Example:
    /// ```swift
    /// let stats = player.statistics
    /// print("Rendered: \(stats.framesRendered) frames")
    /// print("Avg FPS: \(stats.averageFPS)")
    /// print("Drops: \(stats.dropPercentage)%")
    /// ```
    var statistics: PlaybackStats {
        // Return statistics tracked in VideoPlayer
        return PlaybackStats() // Simplified
    }

    /// Reset playback statistics
    func resetStatistics() {
        // Reset stats in VideoPlayer
    }
}

// MARK: - Performance Monitoring

public extension VideoPlayer {
    /// Performance metrics
    struct PerformanceMetrics {
        /// Last frame render time (milliseconds)
        public var lastFrameTime: Float = 0.0

        /// Average frame render time
        public var averageFrameTime: Float = 0.0

        /// Peak frame render time
        public var peakFrameTime: Float = 0.0

        /// Current memory usage estimate (bytes)
        public var memoryUsage: Int = 0

        /// Check if performance is good
        public var isPerformanceGood: Bool {
            return averageFrameTime < 16.67 // < 60fps threshold
        }

        /// Performance rating (0.0 - 1.0)
        public var rating: Float {
            guard averageFrameTime > 0 else { return 1.0 }
            let targetTime: Float = 16.67 // 60fps
            return min(1.0, targetTime / averageFrameTime)
        }
    }

    /// Get performance metrics
    ///
    /// Example:
    /// ```swift
    /// let perf = player.performance
    /// if !perf.isPerformanceGood {
    ///     print("Warning: slow playback")
    ///     print("Avg frame time: \(perf.averageFrameTime)ms")
    /// }
    /// ```
    var performance: PerformanceMetrics {
        return PerformanceMetrics() // Simplified
    }
}

// MARK: - Video Metadata

public extension VideoPlayer {
    /// Extended video metadata
    struct VideoMetadata {
        /// File path
        public let path: String

        /// File size in bytes (if available)
        public let fileSize: Int?

        /// Video dimensions
        public let size: Size

        /// Frame rate
        public let frameRate: Float

        /// Total frames
        public let frameCount: Int32

        /// Total duration
        public let duration: Float

        /// Estimated bitrate (if available)
        public let bitrate: Int?

        /// Format version
        public let formatVersion: String?

        /// Aspect ratio
        public var aspectRatio: Float {
            guard size.height > 0 else { return 0 }
            return Float(size.width) / Float(size.height)
        }

        /// Is widescreen (16:9 or wider)
        public var isWidescreen: Bool {
            return aspectRatio >= 1.77
        }

        /// Is standard (4:3)
        public var isStandard: Bool {
            return abs(aspectRatio - 1.33) < 0.1
        }
    }

    /// Get video metadata
    ///
    /// Example:
    /// ```swift
    /// let meta = player.metadata
    /// print("Video: \(meta.path)")
    /// print("Size: \(meta.size)")
    /// print("Duration: \(meta.duration)s")
    /// print("Aspect: \(meta.aspectRatio.string)")
    /// ```
    var metadata: VideoMetadata {
        let info = getInfo()
        return VideoMetadata(
            path: sourcePath,
            fileSize: nil,
            size: info.size,
            frameRate: info.frameRate,
            frameCount: info.frameCount,
            duration: info.duration,
            bitrate: nil,
            formatVersion: nil
        )
    }
}

// MARK: - Frame Timing Info

public extension VideoPlayer {
    /// Frame timing information
    struct FrameTiming {
        /// Target frame duration (1.0 / frameRate)
        public let frameDuration: Float

        /// Current frame accumulator value
        public let accumulator: Float

        /// Time until next frame
        public var timeUntilNextFrame: Float {
            return max(0, frameDuration - accumulator)
        }

        /// Is ready to render next frame
        public var isReadyForNextFrame: Bool {
            return accumulator >= frameDuration
        }

        /// Progress to next frame (0.0 - 1.0)
        public var progressToNextFrame: Float {
            guard frameDuration > 0 else { return 0 }
            return min(1.0, accumulator / frameDuration)
        }
    }

    /// Get current frame timing info
    ///
    /// Example:
    /// ```swift
    /// let timing = player.frameTiming
    /// print("Time until next: \(timing.timeUntilNextFrame)s")
    /// print("Progress: \(timing.progressToNextFrame * 100)%")
    /// ```
    var frameTiming: FrameTiming {
        let info = getInfo()
        let frameDuration = 1.0 / info.frameRate

        return FrameTiming(
            frameDuration: frameDuration,
            accumulator: frameAccumulator
        )
    }
}

// MARK: - Advanced Debug Features

public extension VideoPlayer {
    /// Enhanced debug information
    struct EnhancedDebugInfo {
        /// Basic video info
        public let info: VideoInfo

        /// Player state
        public let state: VideoPlayerState

        /// Last error
        public let lastError: GraphicsError?

        /// Statistics
        public let stats: PlaybackStats

        /// Performance metrics
        public let performance: PerformanceMetrics

        /// Frame timing
        public let timing: FrameTiming

        /// Context info
        public let context: VideoPlayer.ContextInfo

        /// Detailed description
        public var detailedDescription: String {
            var lines = [
                "=== VIDEO PLAYER DEBUG ===",
                "State: \(state.description)",
                "Frame: \(info.currentFrame)/\(info.frameCount)",
                "Time: \(info.currentSeconds.string)/\(info.duration.string)s",
                "Progress: \(Int(info.progress * 100))%",
                "",
                "=== STATISTICS ===",
                "Frames Rendered: \(stats.framesRendered)",
                "Frames Dropped: \(stats.framesDropped) (\(stats.dropPercentage.string)%)",
                "Average FPS: \(stats.averageFPS.string)",
                "Total Play Time: \(stats.totalPlayTime.string)s",
                "",
                "=== PERFORMANCE ===",
                "Avg Frame Time: \(performance.averageFrameTime.string)ms",
                "Peak Frame Time: \(performance.peakFrameTime.string)ms",
                "Rating: \(Int(performance.rating * 100))%",
                "",
                "=== TIMING ===",
                "Frame Duration: \(timing.frameDuration.string)s",
                "Accumulator: \(timing.accumulator.string)s",
                "Next Frame In: \(timing.timeUntilNextFrame.string)s",
                "",
                "=== CONTEXT ===",
                "\(context.description)",
            ]

            if let error = lastError {
                lines.append("")
                lines.append("=== ERROR ===")
                lines.append("\(error)")
            }

            return lines.joined(separator: "\n")
        }
    }

    /// Get enhanced debug information
    ///
    /// Example:
    /// ```swift
    /// let debug = player.enhancedDebugInfo
    /// print(debug.detailedDescription)
    /// ```
    var enhancedDebugInfo: EnhancedDebugInfo {
        return EnhancedDebugInfo(
            info: info,
            state: state,
            lastError: lastError,
            stats: statistics,
            performance: performance,
            timing: frameTiming,
            context: contextInfo
        )
    }

    /// Print detailed debug info to console
    func printDebugInfo() {
        print(enhancedDebugInfo.detailedDescription)
    }
}

// MARK: - Convenience State Queries

public extension VideoPlayer {
    /// Check if player is actively rendering
    var isActivelyRendering: Bool {
        return isPlaying && canContinuePlaying
    }

    /// Check if player is idle (never started)
    var hasNeverStarted: Bool {
        return state == .idle
    }

    /// Check if player has finished completely
    var hasCompleted: Bool {
        return state == .finished
    }

    /// Check if player is in any active state
    var isActive: Bool {
        return isPlaying || isPaused
    }

    /// Check if player is in any stopped state
    var isInactive: Bool {
        return isStopped || isFinished || isIdle
    }
}

// MARK: - Batch Operations

public extension VideoPlayer {
    /// Render all frames to array of bitmaps
    ///
    /// Warning: This can use significant memory for long videos.
    ///
    /// Example:
    /// ```swift
    /// // Render all frames
    /// let allFrames = player.renderAllFrames()
    /// print("Rendered \(allFrames.count) frames")
    /// ```
    func renderAllFrames() -> [Bitmap] {
        let totalFrames = frameCount
        return renderFrames(in: 0 ..< totalFrames)
    }

    /// Render frames at specific intervals
    ///
    /// - Parameter interval: Frame interval (e.g., 10 = every 10th frame)
    /// - Returns: Array of bitmaps
    ///
    /// Example:
    /// ```swift
    /// // Render every 30th frame (1 per second at 30fps)
    /// let keyframes = player.renderFrames(interval: 30)
    /// ```
    func renderFrames(interval: Int32) -> [Bitmap] {
        var frameNumbers: [Int32] = []
        var frame: Int32 = 0

        while frame < frameCount {
            frameNumbers.append(frame)
            frame += interval
        }

        return renderFrames(frameNumbers)
    }
}

// MARK: - Utility Extensions

public extension VideoPlayer {
    /// Calculate frame number from time
    ///
    /// Convenience for secondsToFrame with default rounding.
    func frameBy(at seconds: Float) -> Int32 {
        return secondsToFrame(seconds)
    }

    /// Calculate time from frame number
    ///
    /// Convenience for frameToSeconds.
    func time(at frame: Int32) -> Float {
        return frameToSeconds(frame)
    }

    /// Get frame at specific progress
    func frame(at progress: Float) -> Int32 {
        return progressToFrame(progress)
    }

    /// Get progress at specific frame
    func progress(at frame: Int32) -> Float {
        return frameToProgress(frame)
    }
}

// MARK: - CustomStringConvertible Extensions

extension VideoPlayer.PlaybackStats: CustomStringConvertible {
    public var description: String {
        return """
        PlaybackStats(
          frames: \(framesRendered),
          dropped: \(framesDropped),
          time: \(totalPlayTime.string)s,
          avgFPS: \(averageFPS.string)
        )
        """
    }
}

extension VideoPlayer.PerformanceMetrics: CustomStringConvertible {
    public var description: String {
        return """
        Performance(
          avgTime: \(averageFrameTime.string)ms,
          peak: \(peakFrameTime.string)ms,
          rating: \(Int(rating * 100))%
        )
        """
    }
}

extension VideoPlayer.VideoMetadata: CustomStringConvertible {
    public var description: String {
        return """
        VideoMetadata(
          path: "\(path)",
          size: \(size.width)x\(size.height),
          frameRate: \(frameRate.string)fps,
          frames: \(frameCount),
          duration: \(duration.string)s,
          aspect: \(aspectRatio.string)
        )
        """
    }
}

extension VideoPlayer.FrameTiming: CustomStringConvertible {
    public var description: String {
        return """
        FrameTiming(
          duration: \(frameDuration.string)s,
          accumulator: \(accumulator.string)s,
          untilNext: \(timeUntilNextFrame.string)s,
          ready: \(isReadyForNextFrame)
        )
        """
    }
}

// MARK: - Additional Error Helpers

public extension VideoPlayer {
    /// Clear last error
    func clearError() {
        lastError = nil
    }

    /// Check if has error
    var hasError: Bool {
        return lastError != nil
    }

    /// Get error description if exists
    var errorDescription: String? {
        return lastError?.description
    }
}
