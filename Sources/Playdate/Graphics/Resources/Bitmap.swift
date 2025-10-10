// Bitmap.swift
// Playdate Graphics Swift SDK
//
// Wrapper for LCDBitmap* with automatic memory management
// Supports both owned and borrowed bitmaps based on API contract

import CPlaydate

// MARK: - Graphics API Accessor

/// Access to Playdate graphics C API
private var graphicsAPI: playdate_graphics {
    playdateAPI.graphics.unsafelyUnwrapped.pointee
}

// MARK: - Bitmap Class

/// Represents a bitmap image in Playdate graphics system
///
/// Bitmaps can be:
/// - Created programmatically (owned)
/// - Loaded from files (owned)
/// - Copied from other bitmaps (owned)
/// - Borrowed from system (borrowed - not freed)
///
/// Memory management is automatic via deinit for owned bitmaps.
public final class Bitmap {
    // MARK: - Private Properties

    /// Pointer to underlying LCDBitmap C structure
    private let pointer: OpaquePointer

    /// Ownership type - determines if bitmap should be freed in deinit
    private let ownership: Ownership

    /// Original file path (if loaded from file)
    private let sourcePath: String?

    /// Ownership model for bitmap memory management
    private enum Ownership {
        case owned // We created it, we free it in deinit
        case borrowed // System owns it, don't free in deinit
    }

    // MARK: - Public Properties - Dimensions

    /// Width of the bitmap in pixels
    public var width: Int32 {
        return getBitmapInfo().width
    }

    /// Height of the bitmap in pixels
    public var height: Int32 {
        return getBitmapInfo().height
    }

    /// Size of the bitmap (width and height)
    public var size: Size {
        let info = getBitmapInfo()
        return Size(width: info.width, height: info.height)
    }

    /// Bounds rectangle of the bitmap (origin at 0,0)
    public var bounds: Rect {
        let info = getBitmapInfo()
        return Rect(x: 0, y: 0, width: info.width, height: info.height)
    }

    /// Original file path if bitmap was loaded from file
    public var path: String? {
        return sourcePath
    }

    // MARK: - Initialization - Creation

    // MARK: - Private Initialization

    /// Internal unsafe initializer - assumes pointer is valid
    private init(ownedPointer ptr: OpaquePointer, sourcePath: String?) {
        pointer = ptr
        ownership = .owned
        self.sourcePath = sourcePath
    }

    /// Internal initializer for borrowed bitmap pointer (system owned)
    /// - Parameter borrowedPointer: Pointer to system-owned bitmap (won't be freed)
    private init(borrowedPointer: OpaquePointer) {
        pointer = borrowedPointer
        ownership = .borrowed
        sourcePath = nil
    }

    // MARK: - Initialization - Creation

    /// Create a new bitmap with specified dimensions and background color
    ///
    /// - Parameters:
    ///   - width: Width in pixels (must be > 0)
    ///   - height: Height in pixels (must be > 0)
    ///   - color: Background color to fill bitmap (default: clear)
    /// - Returns: Result with Bitmap on success or GraphicsError on failure
    ///
    /// Example:
    /// ```swift
    /// switch Bitmap.create(width: 100, height: 100) {
    /// case .success(let bitmap):
    ///     // Use bitmap
    /// case .failure(let error):
    ///     print("Failed to create bitmap: \(error)")
    /// }
    /// ```
    public static func create(
        width: Int32,
        height: Int32,
        color: Color = .clear
    ) -> Result<Bitmap, GraphicsError> {
        guard width > 0, height > 0 else {
            return .failure(.invalidDimensions(width: width, height: height))
        }

        guard let ptr = graphicsAPI.newBitmap(width, height, color.cValue) else {
            return .failure(.memoryAllocationFailed(
                operation: "bitmap creation \(width)x\(height)",
                size: width * height / 8
            ))
        }

        return .success(Bitmap(ownedPointer: ptr, sourcePath: nil))
    }

    /// Create a new bitmap with Size
    ///
    /// - Parameters:
    ///   - size: Dimensions of the bitmap
    ///   - color: Background color to fill bitmap (default: clear)
    /// - Returns: Result with Bitmap on success or GraphicsError on failure
    public static func create(size: Size, color: Color = .clear) -> Result<Bitmap, GraphicsError> {
        return create(width: size.width, height: size.height, color: color)
    }

    // MARK: - Initialization - Loading

    /// Load bitmap from file path
    ///
    /// - Parameter path: Path to bitmap file (relative to project root)
    /// - Returns: Result with Bitmap on success or GraphicsError on failure
    ///
    /// Example:
    /// ```swift
    /// switch Bitmap.load(path: "images/player.png") {
    /// case .success(let bitmap):
    ///     bitmap.draw(at: .zero)
    /// case .failure(let error):
    ///     print("Failed to load bitmap: \(error)")
    /// }
    /// ```
    public static func load(path: String) -> Result<Bitmap, GraphicsError> {
        var errorPtr: UnsafePointer<CChar>?

        guard let ptr = graphicsAPI.loadBitmap(path, &errorPtr) else {
            let errorMessage = errorPtr.map { String(cString: $0) }
                ?? "Unknown error loading bitmap"
            return .failure(.bitmapLoadFailed(
                path: path,
                reason: errorMessage
            ))
        }

        return .success(Bitmap(ownedPointer: ptr, sourcePath: path))
    }

    /// Load bitmap into existing bitmap (replaces content)
    ///
    /// - Parameter path: Path to bitmap file
    /// - Returns: Result with success or GraphicsError on failure
    public func loadInto(path: String) -> Result<Void, GraphicsError> {
        var errorPtr: UnsafePointer<CChar>?

        graphicsAPI.loadIntoBitmap(path, pointer, &errorPtr)

        if let error = errorPtr {
            let errorMessage = String(cString: error)
            return .failure(.bitmapLoadFailed(
                path: path,
                reason: errorMessage
            ))
        }

        return .success(())
    }

    // MARK: - Initialization - Copying

    /// Create a copy of another bitmap
    ///
    /// - Parameter other: Bitmap to copy
    /// - Returns: Result with copied Bitmap on success or GraphicsError on failure
    public static func copy(from other: Bitmap) -> Result<Bitmap, GraphicsError> {
        guard let ptr = graphicsAPI.copyBitmap(other.pointer) else {
            return .failure(.memoryAllocationFailed(
                operation: "bitmap copy \(other.width)x\(other.height)",
                size: other.width * other.height / 8
            ))
        }

        return .success(Bitmap(ownedPointer: ptr, sourcePath: other.sourcePath))
    }

    /// Create a copy of the current display buffer
    ///
    /// - Returns: Result with frame buffer Bitmap on success or GraphicsError on failure
    public static func copyFrameBuffer() -> Result<Bitmap, GraphicsError> {
        guard let ptr = graphicsAPI.copyFrameBufferBitmap() else {
            return .failure(.memoryAllocationFailed(
                operation: "frame buffer copy",
                size: nil
            ))
        }

        return .success(Bitmap(ownedPointer: ptr, sourcePath: nil))
    }

    // MARK: - System Bitmap Access

    /// Get reference to the display buffer bitmap
    ///
    /// - Returns: Result with borrowed bitmap (system owned) or error
    /// - Warning: The system owns this bitmap. Do not attempt to free it.
    ///
    /// Example:
    /// ```swift
    /// switch Bitmap.getDisplayBuffer() {
    /// case .success(let displayBuffer):
    ///     // Work with display buffer
    ///     displayBuffer.draw(at: .zero)
    /// case .failure(let error):
    ///     print("Failed to get display buffer: \(error)")
    /// }
    /// ```
    public static func getDisplayBuffer() -> Result<Bitmap, GraphicsError> {
        guard let ptr = graphicsAPI.getDisplayBufferBitmap() else {
            return .failure(.memoryAllocationFailed(
                operation: "get display buffer",
                size: nil
            ))
        }

        return .success(Bitmap(borrowedPointer: ptr))
    }

    // MARK: - Convenience Failable Initializers

    /// Convenience failable initializer for creating bitmap
    ///
    /// - Parameters:
    ///   - width: Width in pixels
    ///   - height: Height in pixels
    ///   - color: Background color
    /// - Returns: Bitmap instance or nil if creation fails
    public convenience init?(width: Int32, height: Int32, color: Color = .clear) {
        guard width > 0, height > 0 else {
            return nil
        }

        guard let ptr = graphicsAPI.newBitmap(width, height, color.cValue) else {
            return nil
        }

        self.init(ownedPointer: ptr, sourcePath: nil)
    }

    /// Convenience failable initializer for loading bitmap
    ///
    /// - Parameter path: Path to bitmap file
    /// - Returns: Bitmap instance or nil if load fails
    public convenience init?(path: String) {
        var errorPtr: UnsafePointer<CChar>?

        guard let ptr = graphicsAPI.loadBitmap(path, &errorPtr) else {
            return nil
        }

        self.init(ownedPointer: ptr, sourcePath: path)
    }

    /// Convenience failable initializer for copying bitmap
    ///
    /// - Parameter copying: Bitmap to copy
    /// - Returns: Copied bitmap instance or nil if copy fails
    public convenience init?(copying other: Bitmap) {
        guard let ptr = graphicsAPI.copyBitmap(other.pointer) else {
            return nil
        }

        self.init(ownedPointer: ptr, sourcePath: other.sourcePath)
    }

    /// Convenience failable initializer with Size
    ///
    /// - Parameters:
    ///   - size: Dimensions of the bitmap
    ///   - color: Background color
    /// - Returns: Bitmap instance or nil if creation fails
    public convenience init?(size: Size, color: Color = .clear) {
        self.init(width: size.width, height: size.height, color: color)
    }

    // MARK: - Deinitialization

    /// Automatic cleanup - frees bitmap if owned
    deinit {
        if ownership == .owned {
            graphicsAPI.freeBitmap(pointer)
        }
        // borrowed bitmaps are not freed - system owns them
    }

    // MARK: - Internal Access

    /// Internal access to C pointer for rendering operations
    var cPointer: OpaquePointer {
        return pointer
    }
}

// MARK: - Pixel Operations

public extension Bitmap {
    /// Get color of pixel at specified coordinates
    ///
    /// - Parameters:
    ///   - x: X coordinate (0-based)
    ///   - y: Y coordinate (0-based)
    /// - Returns: Solid color at that pixel, or nil if coordinates out of bounds
    func getPixel(x: Int32, y: Int32) -> SolidColor? {
        guard x >= 0, x < width, y >= 0, y < height else {
            return nil
        }

        let colorValue = graphicsAPI.getBitmapPixel(pointer, x, y)
        return SolidColor(rawValue: colorValue.rawValue)
    }

    /// Get color at point
    ///
    /// - Parameter point: Point coordinates
    /// - Returns: Solid color at that point, or nil if out of bounds
    func getPixel(at point: Point) -> SolidColor? {
        return getPixel(x: point.x, y: point.y)
    }

    /// Check if pixel at coordinates is opaque (not clear)
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    /// - Returns: true if pixel is opaque, false if clear or out of bounds
    func isPixelOpaque(x: Int32, y: Int32) -> Bool {
        guard let color = getPixel(x: x, y: y) else {
            return false
        }
        return color != .clear
    }
}

// MARK: - Drawing Context

public extension Bitmap {
    /// Push this bitmap as the current drawing target
    ///
    /// All subsequent drawing operations will render to this bitmap
    /// until popContext() is called.
    ///
    /// - Note: Must be balanced with popContext() or use withContext() instead
    func pushContext() {
        graphicsAPI.pushContext(pointer)
    }

    /// Pop the current drawing context
    ///
    /// Restores the previous drawing target.
    ///
    /// - Note: Must balance previous pushContext() calls
    static func popContext() {
        graphicsAPI.popContext()
    }

    /// Execute a drawing closure with this bitmap as the target
    ///
    /// Automatically handles push/pop context, ensuring cleanup even if
    /// an error is thrown.
    ///
    /// - Parameter draw: Closure to execute with this bitmap as target
    /// - Throws: Rethrows any error from the drawing closure
    ///
    /// Example:
    /// ```swift
    /// try bitmap.withContext {
    ///     Graphics.drawRect(rect: Rect(x: 10, y: 10, width: 50, height: 50))
    ///     Graphics.drawLine(from: Point(x: 0, y: 0), to: Point(x: 100, y: 100))
    /// }
    /// ```
    func withContext<T>(_ draw: () throws -> T) rethrows -> T {
        pushContext()
        defer { Self.popContext() }
        return try draw()
    }
}

// MARK: - Data Access

public extension Bitmap {
    /// Raw bitmap data information
    struct BitmapData {
        /// Width in pixels
        public let width: Int32

        /// Height in pixels
        public let height: Int32

        /// Number of bytes per row (may include padding)
        public let rowBytes: Int32

        /// Whether bitmap has a mask
        public let hasMask: Bool

        /// Pointer to mask data (if exists)
        public let maskData: UnsafeMutablePointer<UInt8>?

        /// Pointer to pixel data
        public let pixelData: UnsafeMutablePointer<UInt8>?
    }

    /// Get raw bitmap data for direct pixel manipulation
    ///
    /// - Returns: BitmapData structure with pointers to pixel data
    /// - Warning: Direct pixel manipulation should be done carefully.
    ///           The data pointers are only valid while the bitmap exists.
    /// Example:
    /// ```swift
    /// let data = bitmap.getData()
    /// if let pixels = data.pixelData {
    ///     // Direct pixel manipulation
    ///     for y in 0..<data.height {
    ///         let rowOffset = y * data.rowBytes
    ///         for x in 0..<data.width {
    ///             let byteIndex = rowOffset + (x / 8)
    ///             let bitIndex = 7 - (x % 8)
    ///             // Manipulate bit at pixels[Int(byteIndex)]
    ///         }
    ///     }
    /// }
    ///
    /// // Access mask data if exists
    /// if data.hasMask, let maskPixels = data.maskData {
    ///     // Process mask data
    /// }
    /// ```

    func getData() -> BitmapData {
        let info = getBitmapInfo()

        return BitmapData(
            width: info.width,
            height: info.height,
            rowBytes: info.rowBytes,
            hasMask: info.hasMask,
            maskData: info.maskData,
            pixelData: info.pixelData
        )
    }

    /// Number of bytes per row in bitmap data
    var rowBytes: Int32 {
        return getBitmapInfo().rowBytes
    }

    /// Check if bitmap has a mask
    var hasMask: Bool {
        return getBitmapInfo().hasMask
    }
}

// MARK: - Clear & Fill

public extension Bitmap {
    /// Clear entire bitmap to specified color
    ///
    /// - Parameter color: Solid color to fill bitmap (default: clear)
    ///
    /// Example:
    /// ```swift
    /// bitmap.clear(color: .white)  // Fill with white
    /// bitmap.clear()               // Clear to transparent
    /// ```
    func clear(color: Color = .clear) {
        graphicsAPI.clearBitmap(pointer, color.cValue)
    }

    /// Fill entire bitmap with white
    func fillWhite() {
        clear(color: .white)
    }

    /// Fill entire bitmap with black
    func fillBlack() {
        clear(color: .black)
    }
}

// MARK: - Transformations

public extension Bitmap {
    /// Create a rotated copy of this bitmap
    ///
    /// - Parameters:
    ///   - rotation: Rotation angle in degrees (clockwise)
    ///   - xScale: Horizontal scale factor (default: 1.0)
    ///   - yScale: Vertical scale factor (default: 1.0)
    /// - Returns: New rotated bitmap
    /// - Throws: GraphicsError if rotation fails
    func rotated(
        by rotation: Float,
        xScale: Float = 1.0,
        yScale: Float = 1.0
    ) throws(GraphicsError) -> Bitmap {
        var allocatedSize: Int32 = 0

        guard let ptr = graphicsAPI.rotatedBitmap(
            pointer,
            rotation,
            xScale,
            yScale,
            &allocatedSize
        ) else {
            throw GraphicsError.bitmapTransformFailed(
                operation: "rotation",
                reason: "Failed to rotate bitmap by \(rotation)°"
            )
        }

        return Bitmap(ownedPointer: ptr, sourcePath: sourcePath)
    }

    /// Create a scaled copy of this bitmap
    ///
    /// - Parameters:
    ///   - xScale: Horizontal scale factor
    ///   - yScale: Vertical scale factor
    /// - Returns: New scaled bitmap
    /// - Throws: GraphicsError if scaling fails
    func scaled(xScale: Float, yScale: Float) throws(GraphicsError) -> Bitmap {
        return try rotated(by: 0, xScale: xScale, yScale: yScale)
    }

    /// Create a scaled copy with uniform scale factor
    ///
    /// - Parameter scale: Uniform scale factor
    /// - Returns: New scaled bitmap
    /// - Throws: GraphicsError if scaling fails
    func scaled(by scale: Float) throws(GraphicsError) -> Bitmap {
        return try scaled(xScale: scale, yScale: scale)
    }

    /// Create a flipped copy of this bitmap
    ///
    /// - Parameter direction: Flip direction (horizontal or vertical)
    /// - Returns: New flipped bitmap
    /// - Throws: GraphicsError if flip fails
    func flipped(_ direction: FlipDirection) throws(GraphicsError) -> Bitmap {
        switch direction {
        case .horizontal:
            return try rotated(by: 0, xScale: -1.0, yScale: 1.0)
        case .vertical:
            return try rotated(by: 0, xScale: 1.0, yScale: -1.0)
        }
    }

    /// Flip direction for bitmap transformations
    enum FlipDirection {
        case horizontal
        case vertical
    }
}

// MARK: - Convenience Properties

public extension Bitmap {
    /// Check if bitmap is empty (all clear pixels)
    var isEmpty: Bool {
        // Quick check: if bitmap has no data, it's considered empty
        guard let data = getData().pixelData else {
            return true
        }

        // Check if all bytes are zero (clear)
        let totalBytes = rowBytes * height
        for i in 0 ..< totalBytes {
            if data[Int(i)] != 0 {
                return false
            }
        }
        return true
    }

    /// Check if this is an owned bitmap (will be freed in deinit)
    var isOwned: Bool {
        return ownership == .owned
    }

    /// Check if this is a borrowed bitmap (system owned, not freed in deinit)
    var isBorrowed: Bool {
        return ownership == .borrowed
    }
}

// MARK: - Mask Operations

public extension Bitmap {
    /// Set a mask bitmap for this bitmap
    ///
    /// - Parameter mask: Mask bitmap, or nil to remove mask
    /// - Throws: GraphicsError if mask operation fails
    ///
    /// Example:
    /// ```swift
    /// let sprite = try Bitmap(path: "images/player.png")
    /// let mask = try Bitmap(path: "images/player-mask.png")
    /// try sprite.setMask(mask)
    /// ```
    func setMask(_ mask: Bitmap?) throws(GraphicsError) {
        let result: Int32

        if let mask = mask {
            result = graphicsAPI.setBitmapMask(pointer, mask.pointer)
        } else {
            result = graphicsAPI.setBitmapMask(pointer, nil)
        }

        if result == 0 {
            throw GraphicsError.maskSetFailed(
                reason: "Failed to set bitmap mask"
            )
        }
    }

    /// Get the mask bitmap for this bitmap
    ///
    /// - Returns: Mask bitmap if one exists, nil otherwise
    /// - Note: The returned bitmap is borrowed from this bitmap's mask.
    ///         It should not be freed separately.
    func getMask() -> Bitmap? {
        guard let maskPtr = graphicsAPI.getBitmapMask(pointer) else {
            return nil
        }
        return Bitmap(borrowedPointer: maskPtr)
    }

    /// Check if bitmap has a mask set
    var hasMaskBitmap: Bool {
        return graphicsAPI.getBitmapMask(pointer) != nil
    }

    /// Remove mask from this bitmap
    ///
    /// - Throws: GraphicsError if mask removal fails
    func removeMask() throws(GraphicsError) {
        try setMask(nil)
    }
}

// MARK: - Equatable

extension Bitmap: Equatable {
    /// Compare two bitmaps for equality
    ///
    /// Bitmaps are considered equal if:
    /// 1. They point to the same underlying C bitmap (identity), OR
    /// 2. They have the same dimensions (width and height)
    ///
    /// - Note: This does NOT compare pixel content for performance reasons
    ///         on resource-constrained Playdate hardware.
    public static func == (lhs: Bitmap, rhs: Bitmap) -> Bool {
        // First check: same pointer (identity)
        if lhs.pointer == rhs.pointer {
            return true
        }

        // Second check: same dimensions
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
}

// MARK: - Hashable

extension Bitmap: Hashable {
    /// Hash bitmap based on pointer identity
    ///
    /// Allows bitmaps to be used in Sets and as Dictionary keys.
    ///
    /// Example:
    /// ```swift
    /// var bitmapCache: [Bitmap: String] = [:]
    /// var uniqueBitmaps: Set<Bitmap> = []
    /// ```
    public func hash(into hasher: inout Hasher) {
        // Hash based on pointer address for identity-based hashing
        hasher.combine(Int(bitPattern: pointer))
    }
}

// MARK: - CustomStringConvertible

extension Bitmap: CustomStringConvertible {
    /// Human-readable description of the bitmap
    ///
    /// Shows dimensions and file path (if loaded from file).
    ///
    /// Example outputs:
    /// - "Bitmap(32x32, path: "images/player.png")"
    /// - "Bitmap(100x100)"
    /// - "Bitmap(400x240, display buffer)"
    public var description: String {
        let dimensions = "\(width)x\(height)"

        // Check if this is display buffer
        if isBorrowed && width == 400 && height == 240 {
            return "Bitmap(\(dimensions), display buffer)"
        }

        // Show path if available
        if let path = sourcePath {
            return "Bitmap(\(dimensions), path: \"\(path)\")"
        }

        // Generic bitmap
        return "Bitmap(\(dimensions))"
    }
}

// MARK: - Additional Utility Methods

public extension Bitmap {
    /// Create a copy of this bitmap with a different mask
    ///
    /// - Parameter mask: Mask bitmap to apply
    /// - Returns: New bitmap with the specified mask
    /// - Throws: GraphicsError if copy or mask operation fails
    func withMask(_ mask: Bitmap) throws(GraphicsError) -> Bitmap {
        // Используем switch вместо .get()
        switch Bitmap.copy(from: self) {
        case let .success(copy):
            try copy.setMask(mask)
            return copy

        case let .failure(error):
            throw error
        }
    }

    /// Check if bitmap is the display buffer
    ///
    /// - Returns: true if this is the borrowed display buffer bitmap
    var isDisplayBuffer: Bool {
        return isBorrowed && width == 400 && height == 240
    }

    /// Calculate memory size in bytes
    ///
    /// - Returns: Approximate memory size of bitmap data
    var memorySize: Int32 {
        let data = getData()
        var size = data.rowBytes * data.height

        // Add mask size if present
        if data.hasMask {
            size += data.rowBytes * data.height
        }

        return size
    }
}

// MARK: - Private Helpers

extension Bitmap {
    /// Internal helper to get bitmap data from C API
    /// Abstracts away all pointer manipulation
    private func getBitmapInfo() -> (
        width: Int32,
        height: Int32,
        rowBytes: Int32,
        hasMask: Bool,
        maskData: UnsafeMutablePointer<UInt8>?,
        pixelData: UnsafeMutablePointer<UInt8>?
    ) {
        var w: Int32 = 0
        var h: Int32 = 0
        var rowbytes: Int32 = 0
        var mask: UnsafeMutablePointer<UInt8>?
        var data: UnsafeMutablePointer<UInt8>?

        // Call C API with correct types
        graphicsAPI.getBitmapData(pointer, &w, &h, &rowbytes, &mask, &data)

        return (
            width: w,
            height: h,
            rowBytes: rowbytes,
            hasMask: mask != nil, // ✅ Check if mask pointer exists
            maskData: mask,
            pixelData: data
        )
    }
}

// MARK: - Debug Helpers

#if DEBUG
    public extension Bitmap {
        /// Debug information about bitmap
        var debugInfo: String {
            var info = """
            Bitmap Debug Info:
            - Dimensions: \(width)x\(height)
            - Row Bytes: \(rowBytes)
            - Memory Size: \(memorySize) bytes
            - Has Mask: \(hasMask)
            - Ownership: \(ownership == .owned ? "owned" : "borrowed")
            """

            if let path = sourcePath {
                info += "\n- Source Path: \(path)"
            }

            if isDisplayBuffer {
                info += "\n- Type: Display Buffer"
            }

            return info
        }

        /// Print debug information to console
        func printDebugInfo() {
            print(debugInfo)
        }
    }
#endif
