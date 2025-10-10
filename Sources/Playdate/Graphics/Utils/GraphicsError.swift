//
//  GraphicsError.swift
//  Playdate Graphics SDK
//
//  Error types for graphics operations and resource loading
//

import CPlaydate

// MARK: - Graphics Error Types

/// Main error type for all graphics-related operations
public enum GraphicsError: Error {
    // MARK: Resource Loading Errors

    /// Failed to load bitmap from file
    /// - Parameters:
    ///   - path: The file path that failed to load
    ///   - reason: Optional C API error message
    case bitmapLoadFailed(path: String, reason: String?)

    /// Failed to load bitmap table from file
    /// - Parameters:
    ///   - path: The file path that failed to load
    ///   - reason: Optional C API error message
    case bitmapTableLoadFailed(path: String, reason: String?)

    /// Failed to load font from file
    /// - Parameters:
    ///   - path: The file path that failed to load
    ///   - reason: Optional C API error message
    case fontLoadFailed(path: String, reason: String?)

    /// Failed to load video from file
    /// - Parameters:
    ///   - path: The file path that failed to load
    ///   - reason: Optional C API error message
    case videoLoadFailed(path: String, reason: String?)

    // MARK: Resource Creation Errors

    /// Failed to create new bitmap in memory
    /// - Parameters:
    ///   - width: Requested bitmap width
    ///   - height: Requested bitmap height
    case bitmapCreationFailed(width: Int32, height: Int32)

    /// Failed to create new bitmap table in memory
    /// - Parameters:
    ///   - count: Requested number of bitmaps
    ///   - width: Requested bitmap width
    ///   - height: Requested bitmap height
    case bitmapTableCreationFailed(count: Int32, width: Int32, height: Int32)

    /// Failed to copy bitmap
    /// - Parameter source: Description of the source bitmap
    case bitmapCopyFailed(source: String)

    /// Failed to rotate bitmap
    /// - Parameters:
    ///   - rotation: Requested rotation angle in degrees
    ///   - scale: Requested scale factor
    case bitmapRotationFailed(rotation: Float, scale: (x: Float, y: Float))

    // MARK: Invalid Parameter Errors

    /// Invalid bitmap index in bitmap table
    /// - Parameters:
    ///   - index: The invalid index
    ///   - count: Valid range (0..<count)
    case invalidBitmapIndex(index: Int32, count: Int32)

    /// Invalid dimensions for graphics operation
    /// - Parameters:
    ///   - width: Provided width
    ///   - height: Provided height
    case invalidDimensions(width: Int32, height: Int32)

    /// Invalid color or pattern
    /// - Parameter description: Description of the invalid color
    case invalidColor(description: String)

    /// Invalid rectangle for clipping or drawing
    /// - Parameter rect: The invalid rectangle
    case invalidRect(x: Int32, y: Int32, width: Int32, height: Int32)

    /// Invalid draw mode
    /// - Parameter mode: The invalid mode value
    case invalidDrawMode(mode: Int32)

    /// Invalid text encoding
    /// - Parameter encoding: The invalid encoding value
    case invalidEncoding(encoding: Int32)

    // MARK: Graphics Context Errors

    /// No graphics context available
    case noContext

    /// Context stack overflow (too many pushContext calls)
    case contextStackOverflow

    /// Context stack underflow (popContext without pushContext)
    case contextStackUnderflow

    /// Invalid context operation
    /// - Parameter reason: Description of why the operation is invalid
    case invalidContextOperation(reason: String)

    // MARK: Video Playback Errors

    /// Video player is not initialized
    case videoPlayerNotInitialized

    /// Failed to render video frame
    /// - Parameters:
    ///   - frame: The frame number that failed
    ///   - reason: Optional C API error message
    case videoFrameRenderFailed(frame: Int32, reason: String?)

    /// Failed to set video context
    /// - Parameter reason: Optional C API error message
    case videoContextSetFailed(reason: String?)

    /// Invalid video frame number
    /// - Parameters:
    ///   - frame: The invalid frame number
    ///   - totalFrames: Total frames in video
    case invalidVideoFrame(frame: Int32, totalFrames: Int32)

    // MARK: Memory Errors

    /// Memory allocation failed
    /// - Parameters:
    ///   - operation: Description of the operation that failed
    ///   - size: Requested memory size in bytes (optional)
    case memoryAllocationFailed(operation: String, size: Int32?)

    /// Out of memory
    case outOfMemory

    // MARK: Null Pointer Errors

    /// C API returned NULL pointer unexpectedly
    /// - Parameters:
    ///   - function: The C function that returned NULL
    ///   - reason: Optional reason for NULL return
    case nullPointerReturned(function: String, reason: String?)

    /// Invalid (NULL) C pointer passed to operation
    /// - Parameter parameter: Name of the parameter that was NULL
    case invalidPointer(parameter: String)

    // MARK: File System Errors

    /// File not found
    /// - Parameter path: The file path that wasn't found
    case fileNotFound(path: String)

    /// File format not supported
    /// - Parameters:
    ///   - path: The file path
    ///   - expectedFormat: Expected file format (e.g., "pdi", "pdt", "fnt")
    case unsupportedFileFormat(path: String, expectedFormat: String)

    /// File is corrupted or invalid
    /// - Parameters:
    ///   - path: The file path
    ///   - reason: Optional reason for corruption
    case corruptedFile(path: String, reason: String?)

    // MARK: Tilemap Errors

    /// Failed to create tilemap
    case tilemapCreationFailed

    /// Invalid tilemap dimensions
    /// - Parameters:
    ///   - tilesWide: Width in tiles
    ///   - tilesHigh: Height in tiles
    case invalidTilemapSize(tilesWide: Int32, tilesHigh: Int32)

    /// Invalid tile position
    /// - Parameters:
    ///   - x: Tile X coordinate
    ///   - y: Tile Y coordinate
    case invalidTilePosition(x: Int32, y: Int32)

    // MARK: Font Errors

    /// Font glyph not found
    /// - Parameters:
    ///   - character: The character code
    ///   - font: Optional font description
    case glyphNotFound(character: UInt32, font: String?)

    /// Font page not found
    /// - Parameters:
    ///   - character: The character code
    ///   - font: Optional font description
    case fontPageNotFound(character: UInt32, font: String?)

    /// Invalid font data
    /// - Parameter reason: Description of the issue
    case invalidFontData(reason: String)

    // MARK: Mask and Pattern Errors

    /// Failed to set bitmap mask
    /// - Parameter reason: Optional reason for failure
    case maskSetFailed(reason: String?)

    /// Invalid pattern dimensions
    /// - Parameter description: Description of the issue
    case invalidPattern(description: String)

    // MARK: Generic Errors

    /// Unknown error occurred
    /// - Parameters:
    ///   - operation: The operation that failed
    ///   - reason: Optional reason
    case unknown(operation: String, reason: String?)

    /// Operation not supported in current context
    /// - Parameter operation: The unsupported operation
    case notSupported(operation: String)

    /// Transformation operation failed
    /// - Parameters:
    ///   - operation: Type of transformation (rotate, scale, flip)
    ///   - message: Error details
    case bitmapTransformFailed(operation: String, reason: String)

    /// Generic error with custom message
    case custom(message: String)
}

// MARK: - Error Description

extension GraphicsError: CustomStringConvertible {
    public var description: String {
        switch self {
        // Resource Loading Errors
        case let .bitmapLoadFailed(path, reason):
            return "Failed to load bitmap from '\(path)'\(reason.map { ": \($0)" } ?? "")"

        case let .bitmapTableLoadFailed(path, reason):
            return "Failed to load bitmap table from '\(path)'\(reason.map { ": \($0)" } ?? "")"

        case let .fontLoadFailed(path, reason):
            return "Failed to load font from '\(path)'\(reason.map { ": \($0)" } ?? "")"

        case let .videoLoadFailed(path, reason):
            return "Failed to load video from '\(path)'\(reason.map { ": \($0)" } ?? "")"

        // Resource Creation Errors
        case let .bitmapCreationFailed(width, height):
            return "Failed to create bitmap with dimensions \(width)x\(height)"

        case let .bitmapTableCreationFailed(count, width, height):
            return "Failed to create bitmap table with \(count) bitmaps of size \(width)x\(height)"

        case let .bitmapCopyFailed(source):
            return "Failed to copy bitmap: \(source)"

        case let .bitmapRotationFailed(rotation, scale):
            return "Failed to rotate bitmap by \(rotation.string)° with scale (\(scale.x.string), \(scale.y.string))"

        // Invalid Parameter Errors
        case let .invalidBitmapIndex(index, count):
            return "Invalid bitmap index \(index), valid range is 0..<\(count)"

        case let .invalidDimensions(width, height):
            return "Invalid dimensions: \(width)x\(height)"

        case let .invalidColor(description):
            return "Invalid color: \(description)"

        case let .invalidRect(x, y, width, height):
            return "Invalid rectangle: origin(\(x), \(y)) size(\(width)x\(height))"

        case let .invalidDrawMode(mode):
            return "Invalid draw mode: \(mode)"

        case let .invalidEncoding(encoding):
            return "Invalid text encoding: \(encoding)"

        // Graphics Context Errors
        case .noContext:
            return "No graphics context available"

        case .contextStackOverflow:
            return "Graphics context stack overflow"

        case .contextStackUnderflow:
            return "Graphics context stack underflow"

        case let .invalidContextOperation(reason):
            return "Invalid context operation: \(reason)"

        // Video Playback Errors
        case .videoPlayerNotInitialized:
            return "Video player is not initialized"

        case let .videoFrameRenderFailed(frame, reason):
            return "Failed to render video frame \(frame)\(reason.map { ": \($0)" } ?? "")"

        case let .videoContextSetFailed(reason):
            return "Failed to set video context\(reason.map { ": \($0)" } ?? "")"

        case let .invalidVideoFrame(frame, totalFrames):
            return "Invalid video frame \(frame), total frames: \(totalFrames)"

        // Memory Errors
        case let .memoryAllocationFailed(operation, size):
            let sizeStr = size.map { " (\($0) bytes)" } ?? ""
            return "Memory allocation failed for \(operation)\(sizeStr)"

        case .outOfMemory:
            return "Out of memory"

        // Null Pointer Errors
        case let .nullPointerReturned(function, reason):
            return "Function '\(function)' returned NULL\(reason.map { ": \($0)" } ?? "")"

        case let .invalidPointer(parameter):
            return "Invalid (NULL) pointer for parameter '\(parameter)'"

        // File System Errors
        case let .fileNotFound(path):
            return "File not found: '\(path)'"

        case let .unsupportedFileFormat(path, expectedFormat):
            return "Unsupported file format for '\(path)', expected '\(expectedFormat)'"

        case let .corruptedFile(path, reason):
            return "Corrupted file '\(path)'\(reason.map { ": \($0)" } ?? "")"

        // Tilemap Errors
        case .tilemapCreationFailed:
            return "Failed to create tilemap"

        case let .invalidTilemapSize(tilesWide, tilesHigh):
            return "Invalid tilemap size: \(tilesWide)x\(tilesHigh) tiles"

        case let .invalidTilePosition(x, y):
            return "Invalid tile position: (\(x), \(y))"

        // Font Errors
        case let .glyphNotFound(character, font):
            let fontStr = font.map { " in font '\($0)'" } ?? ""
            return "Glyph not found for character U+\(String(character, radix: 16, uppercase: true))\(fontStr)"

        case let .fontPageNotFound(character, font):
            let fontStr = font.map { " in font '\($0)'" } ?? ""
            return "Font page not found for character U+\(String(character, radix: 16, uppercase: true))\(fontStr)"

        case let .invalidFontData(reason):
            return "Invalid font data: \(reason)"

        // Mask and Pattern Errors
        case let .maskSetFailed(reason):
            return "Failed to set bitmap mask\(reason.map { ": \($0)" } ?? "")"

        case let .invalidPattern(description):
            return "Invalid pattern: \(description)"

        // Generic Errors
        case let .unknown(operation, reason):
            return "Unknown error in \(operation)\(reason.map { ": \($0)" } ?? "")"

        case let .notSupported(operation):
            return "Operation not supported: \(operation)"

        case let .bitmapTransformFailed(operation, reason):
            return "Operation \(operation) failed by \(reason)"

        case let .custom(message):
            return message
        }
    }
}

// MARK: - Error Factory Methods

extension GraphicsError {
    /// Create error from C API error string
    /// - Parameters:
    ///   - cError: C string pointer from outerr parameter
    ///   - operation: The operation that failed
    /// - Returns: Appropriate GraphicsError case
    static func from(cError: UnsafePointer<CChar>?, operation: String) -> GraphicsError {
        let reason = cError.map { String(cString: $0) }
        return .unknown(operation: operation, reason: reason)
    }

    /// Create error for NULL pointer return
    /// - Parameters:
    ///   - function: The C function name that returned NULL
    ///   - cError: Optional C error string
    /// - Returns: Appropriate GraphicsError case
    static func nullPointer(function: String, cError: UnsafePointer<CChar>? = nil) -> GraphicsError {
        let reason = cError.map { String(cString: $0) }
        return .nullPointerReturned(function: function, reason: reason)
    }
}

public extension Float {
    /// Simple Float to String conversion (2 decimal places)
    var string: String {
        if isNaN { return "NaN" }
        if isInfinite { return self > 0 ? "Inf" : "-Inf" }

        let isNeg = self < 0
        let abs = isNeg ? -self : self
        let int = Int32(abs)
        let frac = Int32((abs - Float(int)) * 100.0 + 0.5)

        var result = isNeg ? "-" : ""
        result += "\(int)."

        if frac < 10 {
            result += "0\(frac)"
        } else {
            result += "\(frac)"
        }

        return result
    }
}

// MARK: - Error Recovery Suggestions

public extension GraphicsError {
    /// Suggests possible ways to recover from or fix the error
    var recoverySuggestion: String? {
        switch self {
        case let .fileNotFound(path):
            return "Verify that '\(path)' exists in the game's resources folder"

        case let .unsupportedFileFormat(_, format):
            return "Ensure the file has the correct '\(format)' format"

        case let .invalidBitmapIndex(_, count):
            return "Use an index between 0 and \(count - 1)"

        case .invalidDimensions:
            return "Dimensions must be positive integers"

        case .memoryAllocationFailed, .outOfMemory:
            return "Free unused resources or reduce memory usage"

        case .contextStackOverflow:
            return "Ensure each pushContext() has a matching popContext()"

        case .contextStackUnderflow:
            return "Don't call popContext() without a prior pushContext()"

        case let .invalidVideoFrame(_, total):
            return "Use a frame number between 0 and \(total - 1)"

        default:
            return nil
        }
    }
}

// MARK: - Error Codes (for C interop)

public extension GraphicsError {
    /// Error domain for NSError bridging (if needed for Objective-C interop)
    static let errorDomain = "com.panic.playdate.graphics"

    /// Numeric error code for each case (useful for logging and debugging)
    var errorCode: Int32 {
        switch self {
        // Resource Loading: 1000-1099
        case .bitmapLoadFailed: return 1000
        case .bitmapTableLoadFailed: return 1001
        case .fontLoadFailed: return 1002
        case .videoLoadFailed: return 1003
        // Resource Creation: 1100-1199
        case .bitmapCreationFailed: return 1100
        case .bitmapTableCreationFailed: return 1101
        case .bitmapCopyFailed: return 1102
        case .bitmapRotationFailed: return 1103
        case .bitmapTransformFailed: return 1104
        // Invalid Parameters: 1200-1299
        case .invalidBitmapIndex: return 1200
        case .invalidDimensions: return 1201
        case .invalidColor: return 1202
        case .invalidRect: return 1203
        case .invalidDrawMode: return 1204
        case .invalidEncoding: return 1205
        // Context Errors: 1300-1399
        case .noContext: return 1300
        case .contextStackOverflow: return 1301
        case .contextStackUnderflow: return 1302
        case .invalidContextOperation: return 1303
        // Video Errors: 1400-1499
        case .videoPlayerNotInitialized: return 1400
        case .videoFrameRenderFailed: return 1401
        case .videoContextSetFailed: return 1402
        case .invalidVideoFrame: return 1403
        // Memory Errors: 1500-1599
        case .memoryAllocationFailed: return 1500
        case .outOfMemory: return 1501
        // Pointer Errors: 1600-1699
        case .nullPointerReturned: return 1600
        case .invalidPointer: return 1601
        // File System Errors: 1700-1799
        case .fileNotFound: return 1700
        case .unsupportedFileFormat: return 1701
        case .corruptedFile: return 1702
        // Tilemap Errors: 1800-1899
        case .tilemapCreationFailed: return 1800
        case .invalidTilemapSize: return 1801
        case .invalidTilePosition: return 1802
        // Font Errors: 1900-1999
        case .glyphNotFound: return 1900
        case .fontPageNotFound: return 1901
        case .invalidFontData: return 1902
        // Mask/Pattern Errors: 2000-2099
        case .maskSetFailed: return 2000
        case .invalidPattern: return 2001
        // Generic Errors: 9000+
        case .unknown: return 9000
        case .notSupported: return 9001
        case .custom: return 9002
        }
    }
}
