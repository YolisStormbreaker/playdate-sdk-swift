// StreamPlayerProtocol.swift (Part 1)
// Protocol definition for future streaming video player implementation
//
// NOTE: This is a PROTOCOL ONLY - no implementation yet.
// Defines the interface for streaming video playback on Playdate.
//
// Implementation challenges for Playdate:
// - Limited RAM (16MB) requires careful buffer management
// - No multithreading - streaming must work on main thread
// - Wi-Fi 802.11bgn 2.4GHz - bandwidth limitations
// - No hardware video decoder - all software decoding
//
// Future implementation will need:
// - Custom networking layer (Playdate network API)
// - Efficient buffer ring for frame data
// - Adaptive quality based on bandwidth
// - Progressive download with playback

import CPlaydate

// MARK: - Stream State

/* WIP
 /// State of streaming video player
 public enum StreamPlayerState: String {
     /// Not initialized
     case idle

     /// Loading stream metadata
     case loading

     /// Buffering initial data
     case buffering

     /// Playing with sufficient buffer
     case playing

     /// Paused by user
     case paused

     /// Stopped and cleared
     case stopped

     /// Rebuffering during playback (buffer depleted)
     case rebuffering

     /// Stream ended
     case finished

     /// Error occurred
     case error

     /// Seeking in stream
     case seeking
 }

 // MARK: - Stream Quality

 /// Video quality level for adaptive streaming
 public enum StreamQuality: String, CaseIterable {
     /// Low quality (smaller bandwidth)
     case low

     /// Medium quality (balanced)
     case medium

     /// High quality (larger bandwidth)
     case high

     /// Auto-select based on bandwidth
     case auto

     /// Estimated bandwidth requirement (KB/s)
     public var estimatedBandwidth: Int {
         switch self {
         case .low: return 50 // 50 KB/s
         case .medium: return 100 // 100 KB/s
         case .high: return 200 // 200 KB/s
         case .auto: return 100 // Default to medium
         }
     }

     /// Target frame rate
     public var targetFrameRate: Float {
         switch self {
         case .low: return 15.0
         case .medium: return 20.0
         case .high: return 30.0
         case .auto: return 20.0
         }
     }
 }

 // MARK: - Buffer Info

 /// Information about stream buffer
 public struct StreamBufferInfo {
     /// Current buffer level (seconds of video)
     public let bufferLevel: Float

     /// Target buffer size (seconds)
     public let targetBuffer: Float

     /// Maximum buffer size (seconds)
     public let maxBuffer: Float

     /// Current buffer percentage (0.0 - 1.0)
     public var bufferPercentage: Float {
         guard maxBuffer > 0 else { return 0 }
         return min(1.0, bufferLevel / maxBuffer)
     }

     /// Is buffer healthy (above target)
     public var isHealthy: Bool {
         return bufferLevel >= targetBuffer
     }

     /// Is buffer low (below target)
     public var isLow: Bool {
         return bufferLevel < targetBuffer
     }

     /// Is buffer critical (near empty)
     public var isCritical: Bool {
         return bufferLevel < targetBuffer * 0.25
     }
 }

 // MARK: - Stream Info

 /// Information about streaming video
 public struct StreamInfo {
     /// Stream URL
     public let url: String

     /// Current quality level
     public let quality: StreamQuality

     /// Video dimensions
     public let width: Int32
     public let height: Int32

     /// Frame rate
     public let frameRate: Float

     /// Total duration (if known, nil for live streams)
     public let duration: Float?

     /// Current playback position
     public let currentTime: Float

     /// Is live stream (no seeking)
     public let isLive: Bool

     /// Current download speed (KB/s)
     public let downloadSpeed: Float

     /// Buffer information
     public let buffer: StreamBufferInfo

     /// Playback progress (0.0 - 1.0, nil for live)
     public var progress: Float? {
         guard let dur = duration, dur > 0 else { return nil }
         return currentTime / dur
     }

     /// Size as Size struct
     public var size: Size {
         return Size(width: width, height: height)
     }
 }

 // MARK: - Network State

 /// Network connection state
 public enum NetworkState: String {
     /// No network connection
     case disconnected

     /// Connecting to server
     case connecting

     /// Connected and streaming
     case connected

     /// Connection unstable
     case unstable

     /// Connection lost, attempting reconnect
     case reconnecting
 }

 // MARK: - Stream Player Protocol

 /// Protocol for streaming video player
 ///
 /// # Overview
 ///
 /// This protocol defines the interface for a streaming video player
 /// optimized for Playdate's constraints:
 /// - Limited RAM (16MB)
 /// - Single-threaded processing
 /// - Wi-Fi bandwidth limitations
 /// - Software-only video decoding
 ///
 /// # Implementation Requirements
 ///
 /// A conforming implementation must:
 /// 1. Handle progressive download and playback simultaneously
 /// 2. Manage circular frame buffer efficiently
 /// 3. Adapt quality based on available bandwidth
 /// 4. Support pause/resume with buffer retention
 /// 5. Handle network interruptions gracefully
 /// 6. Provide accurate buffer status
 ///
 /// # Buffer Management Strategy
 ///
 /// ```
 /// [Downloaded Frames] → [Ring Buffer] → [Playback]
 ///        ↓                    ↓              ↓
 ///    Network              Memory          Display
 ///   (Wi-Fi)            (16MB limit)      (400x240)
 /// ```
 ///
 /// Recommended buffer sizes:
 /// - Target: 2-3 seconds of video
 /// - Maximum: 5 seconds (memory constraint)
 /// - Minimum: 0.5 seconds (rebuffer threshold)
 ///
 /// # Usage Example
 ///
 /// ```swift
 /// // Future implementation usage:
 /// let player = StreamPlayer() // Hypothetical implementation
 /// player.onBufferUpdate = { buffer in
 ///     print("Buffer: \(buffer.bufferPercentage * 100)%")
 /// }
 ///
 /// player.load(url: "http://example.com/video.pdv", quality: .auto)
 /// player.play()
 ///
 /// // In game loop:
 /// func update() {
 ///     player.update()
 ///     player.render()
 /// }
 /// ```
 public protocol StreamPlayerProtocol: AnyObject {
     // MARK: - State Properties

     /// Current player state
     var state: StreamPlayerState { get }

     /// Current stream information
     var streamInfo: StreamInfo? { get }

     /// Current network state
     var networkState: NetworkState { get }

     /// Is currently streaming
     var isStreaming: Bool { get }

     /// Is currently playing
     var isPlaying: Bool { get }

     /// Is buffering
     var isBuffering: Bool { get }

     /// Is paused
     var isPaused: Bool { get }

     // MARK: - Buffer Properties

     /// Current buffer status
     var bufferInfo: StreamBufferInfo { get }

     /// Is buffer healthy
     var isBufferHealthy: Bool { get }

     /// Target buffer size (seconds)
     var targetBufferSize: Float { get set }

     /// Maximum buffer size (seconds)
     var maxBufferSize: Float { get set }

     // MARK: - Quality Properties

     /// Current stream quality
     var currentQuality: StreamQuality { get }

     /// Available quality levels
     var availableQualities: [StreamQuality] { get }

     /// Enable adaptive quality (auto-adjust based on bandwidth)
     var adaptiveQualityEnabled: Bool { get set }

     // MARK: - Network Properties

     /// Current download speed (KB/s)
     var downloadSpeed: Float { get }

     /// Average download speed (KB/s)
     var averageDownloadSpeed: Float { get }

     /// Network bandwidth estimate (KB/s)
     var estimatedBandwidth: Float { get }

     /// Is network stable
     var isNetworkStable: Bool { get }

     // MARK: - Callbacks

     /// Called when state changes
     var onStateChange: ((StreamPlayerState) -> Void)? { get set }

     /// Called when buffering progress updates
     var onBufferUpdate: ((StreamBufferInfo) -> Void)? { get set }

     /// Called when quality changes
     var onQualityChange: ((StreamQuality) -> Void)? { get set }

     /// Called when network state changes
     var onNetworkStateChange: ((NetworkState) -> Void)? { get set }

     /// Called on streaming error
     var onError: ((GraphicsError) -> Void)? { get set }

     /// Called when stream ends
     var onStreamEnd: (() -> Void)? { get set }

     // MARK: - Core Streaming Methods

     /// Load stream from URL
     ///
     /// Initiates connection to stream URL and begins loading metadata.
     ///
     /// - Parameters:
     ///   - url: Stream URL (http://... or https://...)
     ///   - quality: Desired quality level
     ///   - autoPlay: Start playing when ready (default: true)
     /// - Returns: true if load initiated successfully
     ///
     /// # Implementation Notes
     ///
     /// Must perform:
     /// 1. Network connection to URL
     /// 2. Stream metadata parsing
     /// 3. Initial buffer allocation
     /// 4. Quality selection (if auto)
     ///
     /// Example:
     /// ```swift
     /// player.load(
     ///     url: "http://server.com/video.pdv",
     ///     quality: .auto,
     ///     autoPlay: true
     /// )
     /// ```
     func load(url: String, quality: StreamQuality, autoPlay: Bool) -> Bool

     /// Start or resume streaming playback
     ///
     /// Begins playback if buffer has sufficient data.
     /// May enter buffering state if buffer is low.
     ///
     /// - Returns: true if playback started
     func play() -> Bool

     /// Pause streaming playback
     ///
     /// Pauses playback but continues downloading to buffer.
     ///
     /// - Returns: true if paused successfully
     func pause() -> Bool

     /// Stop streaming and clear buffer
     ///
     /// Stops playback, closes network connection, and clears all buffers.
     /// Must call load() again to restart.
     func stop()

     /// Update streaming state (call every frame)
     ///
     /// Must be called in game loop to:
     /// - Process downloaded data
     /// - Update buffer status
     /// - Check network state
     /// - Trigger quality adjustments
     ///
     /// Example:
     /// ```swift
     /// func gameUpdate() {
     ///     player.update()
     /// }
     /// ```
     func update()

     /// Render current frame to context
     ///
     /// Renders the current buffered frame.
     /// Does not advance playback (that happens in update()).
     ///
     /// - Returns: true if frame rendered successfully
     func render() -> Bool

     // MARK: - Buffer Control

     /// Manually trigger buffering
     ///
     /// Forces player to enter buffering state and fill buffer
     /// to target level before resuming playback.
     func buffer()

     /// Clear all buffered data
     ///
     /// Clears frame buffer. Useful for seeking or quality changes.
     /// Playback will need to rebuffer.
     func clearBuffer()

     /// Get number of frames in buffer
     var bufferedFrameCount: Int32 { get }

     /// Get buffer memory usage (bytes)
     var bufferMemoryUsage: Int { get }

     // MARK: - Quality Control

     /// Change stream quality
     ///
     /// Switches to different quality level. Will cause rebuffering.
     ///
     /// - Parameter quality: New quality level
     /// - Returns: true if quality change initiated
     ///
     /// Example:
     /// ```swift
     /// // Switch to low quality to save bandwidth
     /// player.setQuality(.low)
     /// ```
     func setQuality(_ quality: StreamQuality) -> Bool

     /// Get recommended quality for current bandwidth
     ///
     /// - Returns: Recommended quality level based on network conditions
     func recommendedQuality() -> StreamQuality
 }

 // MARK: - Protocol Extensions

 public extension StreamPlayerProtocol {
     /// Check if can play (buffer ready)
     var canPlay: Bool {
         return isBufferHealthy && networkState == .connected
     }

     /// Check if needs buffering
     var needsBuffering: Bool {
         return bufferInfo.isCritical
     }

     /// Buffer level percentage (0-100)
     var bufferPercentage: Float {
         return bufferInfo.bufferPercentage * 100.0
     }

     /// Is loading (connecting or initial buffering)
     var isLoading: Bool {
         return state == .loading || state == .buffering
     }

     /// Is in error state
     var hasError: Bool {
         return state == .error
     }

     /// Check if stream is live (no seeking)
     var isLive: Bool {
         return streamInfo?.isLive ?? false
     }

     /// Check if stream supports seeking
     var canSeek: Bool {
         return !isLive
     }
 }

 // StreamPlayerProtocol.swift (Part 2)
 // Advanced streaming features, network management, and implementation notes

 import CPlaydate

 // MARK: - StreamPlayerProtocol (Advanced Features)

 public extension StreamPlayerProtocol {
     // MARK: - Advanced Seeking (Non-Live Streams)

     /// Seek to specific time in stream
     ///
     /// # Implementation Requirements
     ///
     /// For non-live streams, must:
     /// 1. Clear current buffer
     /// 2. Request new stream position from server
     /// 3. Enter rebuffering state
     /// 4. Resume when buffer ready
     ///
     /// For live streams, should return false (no seeking).
     ///
     /// - Parameter seconds: Target time in seconds
     /// - Returns: true if seek initiated (will rebuffer)
     ///
     /// Example:
     /// ```swift
     /// if player.canSeek {
     ///     player.seek(toSeconds: 30.0) // Jump to 30s
     /// }
     /// ```
     func seek(toSeconds seconds: Float) -> Bool

     /// Seek to progress (0.0 - 1.0)
     ///
     /// - Parameter progress: Target progress
     /// - Returns: true if seek initiated
     func seek(toProgress progress: Float) -> Bool

     /// Skip forward by seconds
     ///
     /// - Parameter seconds: Seconds to skip
     /// - Returns: true if skip initiated
     func skipForward(seconds: Float) -> Bool

     /// Skip backward by seconds
     ///
     /// - Parameter seconds: Seconds to skip back
     /// - Returns: true if skip initiated
     func skipBackward(seconds: Float) -> Bool
 }

 // MARK: - Adaptive Quality Management

 /// Adaptive quality configuration
 public struct AdaptiveQualityConfig {
     /// Enable adaptive quality
     public var enabled: Bool = true

     /// Minimum quality level (won't go below this)
     public var minimumQuality: StreamQuality = .low

     /// Maximum quality level (won't exceed this)
     public var maximumQuality: StreamQuality = .high

     /// Upgrade threshold (bandwidth % above requirement)
     public var upgradeThreshold: Float = 1.5 // 150% of required

     /// Downgrade threshold (bandwidth % below requirement)
     public var downgradeThreshold: Float = 0.8 // 80% of required

     /// Time to wait before upgrading (seconds)
     public var upgradeDelay: Float = 5.0

     /// Time to wait before downgrading (seconds)
     public var downgradeDelay: Float = 2.0

     /// Consider buffer health in decisions
     public var considerBufferHealth: Bool = true
 }

 public extension StreamPlayerProtocol {
     /// Configure adaptive quality behavior
     var adaptiveQualityConfig: AdaptiveQualityConfig { get set }

     /// Force quality re-evaluation
     ///
     /// Triggers immediate check of current bandwidth and buffer
     /// to determine if quality should change.
     func evaluateQuality()
 }

 // MARK: - Network Management

 /// Network reconnection strategy
 public enum ReconnectionStrategy {
     /// Don't reconnect automatically
     case manual

     /// Reconnect immediately on disconnect
     case immediate

     /// Reconnect with exponential backoff
     case exponentialBackoff(
         initialDelay: Float, // Initial delay (seconds)
         maxDelay: Float, // Max delay (seconds)
         maxAttempts: Int // Max reconnection attempts
     )

     /// Default strategy for Playdate
     public static var playdate: ReconnectionStrategy {
         return .exponentialBackoff(
             initialDelay: 1.0,
             maxDelay: 30.0,
             maxAttempts: 5
         )
     }
 }

 /// Network statistics
 public struct NetworkStatistics {
     /// Total bytes downloaded
     public var bytesDownloaded: Int = 0

     /// Total packets received
     public var packetsReceived: Int = 0

     /// Packets dropped
     public var packetsDropped: Int = 0

     /// Current latency (milliseconds)
     public var latency: Float = 0

     /// Average latency (milliseconds)
     public var averageLatency: Float = 0

     /// Packet loss rate (0.0 - 1.0)
     public var packetLossRate: Float {
         let total = packetsReceived + packetsDropped
         guard total > 0 else { return 0 }
         return Float(packetsDropped) / Float(total)
     }

     /// Network quality rating (0.0 - 1.0)
     public var qualityRating: Float {
         // Based on packet loss and latency
         let lossScore = 1.0 - min(1.0, packetLossRate * 10.0)
         let latencyScore = 1.0 - min(1.0, averageLatency / 1000.0)
         return (lossScore + latencyScore) / 2.0
     }
 }

 public extension StreamPlayerProtocol {
     /// Reconnection strategy
     var reconnectionStrategy: ReconnectionStrategy { get set }

     /// Current reconnection attempt
     var reconnectionAttempt: Int { get }

     /// Is currently reconnecting
     var isReconnecting: Bool { get }

     /// Network statistics
     var networkStats: NetworkStatistics { get }

     /// Manually trigger reconnection
     ///
     /// Forces reconnection attempt even if automatic reconnection
     /// is disabled or max attempts reached.
     ///
     /// - Returns: true if reconnection initiated
     func reconnect() -> Bool

     /// Cancel ongoing reconnection
     func cancelReconnection()
 }

 // MARK: - Cache Management

 /// Cache configuration
 public struct StreamCacheConfig {
     /// Enable caching
     public var enabled: Bool = false

     /// Maximum cache size (bytes)
     public var maxSize: Int = 5_000_000 // 5MB default

     /// Cache location (path)
     public var cachePath: String = "StreamCache/"

     /// Auto-delete old cache
     public var autoDeleteOld: Bool = true

     /// Max age of cached data (seconds)
     public var maxAge: Float = 3600.0 // 1 hour
 }

 /// Cache statistics
 public struct CacheStatistics {
     /// Total cache size (bytes)
     public var totalSize: Int = 0

     /// Number of cached segments
     public var segmentCount: Int = 0

     /// Cache hit rate (0.0 - 1.0)
     public var hitRate: Float = 0

     /// Bytes saved by cache
     public var bytesSaved: Int = 0
 }

 public extension StreamPlayerProtocol {
     /// Cache configuration
     var cacheConfig: StreamCacheConfig { get set }

     /// Cache statistics
     var cacheStats: CacheStatistics { get }

     /// Is caching enabled
     var isCachingEnabled: Bool { get }

     /// Clear all cached data
     func clearCache()

     /// Get cache size (bytes)
     func getCacheSize() -> Int
 }

 // MARK: - Stream Statistics

 /// Comprehensive streaming statistics
 public struct StreamStatistics {
     /// Total frames received
     public var framesReceived: Int = 0

     /// Frames rendered
     public var framesRendered: Int = 0

     /// Frames dropped
     public var framesDropped: Int = 0

     /// Total rebuffer events
     public var rebufferCount: Int = 0

     /// Total rebuffer time (seconds)
     public var totalRebufferTime: Float = 0

     /// Total playback time (seconds)
     public var totalPlayTime: Float = 0

     /// Quality changes count
     public var qualityChanges: Int = 0

     /// Network reconnections
     public var reconnections: Int = 0

     /// Average frame rate
     public var averageFPS: Float {
         guard totalPlayTime > 0 else { return 0 }
         return Float(framesRendered) / totalPlayTime
     }

     /// Frame drop rate (0.0 - 1.0)
     public var dropRate: Float {
         let total = framesRendered + framesDropped
         guard total > 0 else { return 0 }
         return Float(framesDropped) / Float(total)
     }

     /// Rebuffer ratio (time spent rebuffering / total time)
     public var rebufferRatio: Float {
         let totalTime = totalPlayTime + totalRebufferTime
         guard totalTime > 0 else { return 0 }
         return totalRebufferTime / totalTime
     }

     /// Overall quality score (0.0 - 1.0)
     public var qualityScore: Float {
         let fpsScore = min(1.0, averageFPS / 30.0)
         let dropScore = 1.0 - min(1.0, dropRate * 10.0)
         let rebufferScore = 1.0 - min(1.0, rebufferRatio * 5.0)
         return (fpsScore + dropScore + rebufferScore) / 3.0
     }
 }

 public extension StreamPlayerProtocol {
     /// Streaming statistics
     var streamStats: StreamStatistics { get }

     /// Reset statistics
     func resetStatistics()
 }

 // MARK: - Context Management

 public extension StreamPlayerProtocol {
     /// Set render context
     ///
     /// Changes where stream frames are rendered.
     ///
     /// - Parameter context: Render context (.screen or .bitmap)
     /// - Returns: true if context set successfully
     func setContext(_ context: VideoContext) -> Bool

     /// Get current render context
     func getContext() -> Bitmap?
 }

 // MARK: - Debug Features

 #if DEBUG
     public extension StreamPlayerProtocol {
         /// Enable debug overlay
         var showDebugOverlay: Bool { get set }

         /// Debug overlay position
         var debugOverlayPosition: Point { get set }

         /// Get detailed debug information
         var debugInfo: String { get }

         /// Print debug information to console
         func printDebugInfo()
     }
 #endif

 // MARK: - CustomStringConvertible Extensions

 extension StreamPlayerState: CustomStringConvertible {
     public var description: String {
         return rawValue
     }
 }

 extension StreamQuality: CustomStringConvertible {
     public var description: String {
         return "\(rawValue) (\(targetFrameRate)fps, \(estimatedBandwidth)KB/s)"
     }
 }

 extension NetworkState: CustomStringConvertible {
     public var description: String {
         return rawValue
     }
 }

 extension StreamBufferInfo: CustomStringConvertible {
     public var description: String {
         return String(
             format: "Buffer: %.1f/%.1fs (%.0f%%)",
             bufferLevel,
             maxBuffer,
             bufferPercentage * 100
         )
     }
 }

 extension StreamInfo: CustomStringConvertible {
     public var description: String {
         var desc = """
         StreamInfo(
           url: \(url)
           quality: \(quality)
           size: \(width)x\(height)
           fps: \(String(format: "%.1f", frameRate))
           time: \(String(format: "%.1f", currentTime))s
         """

         if let dur = duration {
             desc += "\n  duration: \(String(format: "%.1f", dur))s"
         }

         desc += "\n  live: \(isLive)"
         desc += "\n  speed: \(String(format: "%.1f", downloadSpeed))KB/s"
         desc += "\n  \(buffer.description)"
         desc += "\n)"

         return desc
     }
 }

 extension NetworkStatistics: CustomStringConvertible {
     public var description: String {
         return """
         NetworkStats(
           downloaded: \(bytesDownloaded / 1024)KB
           packets: \(packetsReceived) (dropped: \(packetsDropped))
           loss: \(String(format: "%.1f%%", packetLossRate * 100))
           latency: \(String(format: "%.0f", averageLatency))ms
           quality: \(String(format: "%.1f%%", qualityRating * 100))
         )
         """
     }
 }

 extension StreamStatistics: CustomStringConvertible {
     public var description: String {
         return """
         StreamStats(
           frames: \(framesRendered)/\(framesReceived) (dropped: \(framesDropped))
           avgFPS: \(String(format: "%.1f", averageFPS))
           dropRate: \(String(format: "%.1f%%", dropRate * 100))
           rebuffers: \(rebufferCount) (\(String(format: "%.1fs", totalRebufferTime)))
           quality: \(String(format: "%.1f%%", qualityScore * 100))
         )
         """
     }
 }

 */

// MARK: - Implementation Notes

/*
 # IMPLEMENTATION NOTES FOR StreamPlayerProtocol

 ## Architecture Overview

 A streaming video player for Playdate must balance several constraints:

 1. **Memory (16MB RAM)**
 - Keep buffer size small (2-5 seconds typical)
 - Use ring buffer for frame storage
 - Release frames immediately after rendering

 2. **Single Thread**
 - Network operations must be non-blocking
 - Use Playdate's async network API
 - Process data in small chunks per frame

 3. **Network (Wi-Fi 2.4GHz)**
 - Expect 1-10 Mbps typical bandwidth
 - Handle packet loss gracefully
 - Implement exponential backoff for retries

 4. **Processing (168MHz ARM)**
 - Video decoding is CPU-intensive
 - Prefer lower resolution/framerate
 - Consider frame dropping over rebuffering

 ## Recommended Buffer Strategy
 Target Buffer: 2 seconds
 Max Buffer: 5 seconds
 Rebuffer Threshold: 0.5 seconds

 States:

 Buffering: buffer < target
 Playing: buffer >= target && buffer < max
 Full: buffer >= max (pause download)
 Critical: buffer < threshold (pause playback)

 ## Quality Adaptation Algorithm

 ```swift
 func shouldUpgradeQuality() -> Bool {
 // Check bandwidth
 guard downloadSpeed > currentQuality.estimatedBandwidth * 1.5 else {
 return false
 }

 // Check buffer health
 guard bufferInfo.bufferLevel > targetBufferSize * 1.5 else {
 return false
 }

 // Check stability
 guard networkState == .connected else {
 return false
 }

 return true
 }

 func shouldDowngradeQuality() -> Bool {
 // Check bandwidth
 if downloadSpeed < currentQuality.estimatedBandwidth * 0.8 {
 return true
 }

 // Check buffer
 if bufferInfo.isCritical {
 return true
 }

 // Check packet loss
 if networkStats.packetLossRate > 0.1 {
 return true
 }

 return false
 }

 ## Network Reconnection Strategy

  ```swift
  var reconnectDelay: Float = 1.0
  let maxReconnectDelay: Float = 30.0

  func onDisconnect() {
 state = .reconnecting
 scheduleReconnect(after: reconnectDelay)

 // Exponential backoff
 reconnectDelay = min(reconnectDelay * 2.0, maxReconnectDelay)
  }

  func onReconnectSuccess() {
 // Reset delay
 reconnectDelay = 1.0
 state = .buffering
  }
  ```

  ## Frame Buffer Implementation

  ```swift
  // Ring buffer for frames
  class FrameBuffer {
 private var frames: [VideoFrame] = []
 private var capacity: Int
 private var readIndex: Int = 0
 private var writeIndex: Int = 0

 var count: Int {
 return frames.count
 }

 var isFull: Bool {
 return count >= capacity
 }

 func push(_ frame: VideoFrame) {
 guard !isFull else { return }
 frames.append(frame)
 }

 func pop() -> VideoFrame? {
 guard !frames.isEmpty else { return nil }
 return frames.removeFirst()
 }

 func clear() {
 frames.removeAll()
 readIndex = 0
 writeIndex = 0
 }
  }
  ```

  ## Performance Targets

  For smooth playback on Playdate:

  - Frame render time: < 16ms (60fps device)
  - Network processing: < 5ms per frame
  - Buffer management: < 2ms per frame
  - Total overhead: < 25% of frame time

  ## Testing Recommendations

  1. **Network Conditions**
 - Test with varying bandwidth (1-10 Mbps)
 - Simulate packet loss (5-20%)
 - Test disconnection/reconnection

  2. **Buffer Scenarios**
 - Start with empty buffer
 - Deplete buffer during playback
 - Overflow buffer (should pause download)

  3. **Quality Transitions**
 - Smooth quality changes
 - No visible glitches
 - Fast adaptation to conditions

  4. **Memory Usage**
 - Monitor peak memory
 - Verify buffer limits enforced
 - Check for memory leaks

  ## C API Integration

  The implementation will need to:

  1. Use Playdate File API for network I/O
  2. Use Video API for frame decoding
  3. Use Graphics API for rendering
  4. Use System API for timing

  Example pseudo-code:

  ```c
  // Download chunk
  void download_chunk(const char* url, int offset) {
 SDFile* file = playdate->file->open(url, kFileRead);
 // Read data...
 // Parse into frames...
 playdate->file->close(file);
  }

  // Decode frame
  LCDVideoPlayer* player = ...;
  playdate->graphics->video->renderFrame(player, frameNumber);
  ```

  ## Known Limitations

  1. No hardware video decoder
 - All decoding in software
 - CPU-intensive for high resolution

  2. Single-threaded
 - Can't download and decode simultaneously
 - Must time-slice operations

  3. Limited RAM
 - Can't buffer many frames
 - Frequent rebuffering on slow networks

  4. Wi-Fi only
 - No cellular fallback
 - Range-limited

  ## Future Enhancements

  Possible improvements:

  - Pre-caching of popular streams
  - Peer-to-peer streaming between Playdates
  - Low-latency streaming for multiplayer
  - Audio streaming support
  - Playlist/queue management
  */
