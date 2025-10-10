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

    // MARK: - Initialization

    /// Internal unsafe initializer - assumes pointer is valid
    public init(ownedPointer ptr: OpaquePointer, _ sourcePath: String? = nil) {
        pointer = ptr
        ownership = .owned
        self.sourcePath = sourcePath
    }

    /// Internal initializer for borrowed bitmap pointer (system owned)
    /// - Parameter borrowedPointer: Pointer to system-owned bitmap (won't be freed)
    public init(borrowedPointer: OpaquePointer) {
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

        return .success(Bitmap(ownedPointer: ptr, nil))
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

        return .success(Bitmap(ownedPointer: ptr, path))
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

        return .success(Bitmap(ownedPointer: ptr, other.sourcePath))
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

        return .success(Bitmap(ownedPointer: ptr, nil))
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

        self.init(ownedPointer: ptr, nil)
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

        self.init(ownedPointer: ptr, path)
    }

    /// Convenience failable initializer for copying bitmap
    ///
    /// - Parameter copying: Bitmap to copy
    /// - Returns: Copied bitmap instance or nil if copy fails
    public convenience init?(copying other: Bitmap) {
        guard let ptr = graphicsAPI.copyBitmap(other.pointer) else {
            return nil
        }

        self.init(ownedPointer: ptr, other.sourcePath)
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
        return SolidColor(rawValue: UInt32(colorValue.rawValue))
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

// MARK: - Drawing Methods

public extension Bitmap {
    /// Draw bitmap at specified position
    ///
    /// Draws this bitmap with its upper-left corner at the given coordinates.
    ///
    /// - Parameters:
    ///   - x: X coordinate for upper-left corner
    ///   - y: Y coordinate for upper-left corner
    ///   - flip: Bitmap flip mode (default: unflipped)
    ///
    /// From Playdate SDK:
    /// > "Draws the bitmap with its upper-left corner at location x, y,
    /// > using the given flip orientation."
    ///
    /// Example:
    /// ```swift
    /// // Draw bitmap at position
    /// bitmap.draw(at: 100, 50)
    ///
    /// // Draw flipped horizontally
    /// bitmap.draw(at: 100, 50, flip: .flippedX)
    ///
    /// // Draw flipped vertically
    /// bitmap.draw(at: 100, 50, flip: .flippedY)
    ///
    /// // Draw flipped both ways
    /// bitmap.draw(at: 100, 50, flip: .flippedXY)
    /// ```
    func draw(at x: Int32, _ y: Int32, flip: BitmapFlip = .unflipped) {
        graphicsAPI.drawBitmap(pointer, x, y, flip.cValue)
    }

    /// Draw bitmap at Point
    ///
    /// - Parameters:
    ///   - point: Position for upper-left corner
    ///   - flip: Bitmap flip mode (default: unflipped)
    ///
    /// Example:
    /// ```swift
    /// let position = Point(x: 100, y: 50)
    /// bitmap.draw(at: position)
    ///
    /// // With flip
    /// bitmap.draw(at: position, flip: .flippedX)
    /// ```
    func draw(at point: Point, flip: BitmapFlip = .unflipped) {
        draw(at: point.x, point.y, flip: flip)
    }

    /// Draw bitmap with origin at zero
    ///
    /// Convenience method for drawing at (0, 0)
    ///
    /// Example:
    /// ```swift
    /// bitmap.draw()  // Draw at (0, 0)
    /// bitmap.draw(flip: .flippedX)  // Draw at (0, 0) flipped
    /// ```
    func draw(flip: BitmapFlip = .unflipped) {
        draw(at: 0, 0, flip: flip)
    }

    /// Draw bitmap centered at specified position
    ///
    /// Calculates position so that bitmap center is at (x, y)
    ///
    /// - Parameters:
    ///   - x: X coordinate for center
    ///   - y: Y coordinate for center
    ///   - flip: Bitmap flip mode
    ///
    /// Example:
    /// ```swift
    /// // Draw centered on screen
    /// bitmap.drawCentered(at: 200, 120)
    /// ```
    func drawCentered(at x: Int32, _ y: Int32, flip: BitmapFlip = .unflipped) {
        let centerX = x - (width / 2)
        let centerY = y - (height / 2)
        draw(at: centerX, centerY, flip: flip)
    }

    /// Draw bitmap centered at Point
    ///
    /// - Parameters:
    ///   - point: Center position
    ///   - flip: Bitmap flip mode
    ///
    /// Example:
    /// ```swift
    /// let screenCenter = Point(x: 200, y: 120)
    /// bitmap.drawCentered(at: screenCenter)
    /// ```
    func drawCentered(at point: Point, flip: BitmapFlip = .unflipped) {
        drawCentered(at: point.x, point.y, flip: flip)
    }

    /// Draw bitmap centered on screen
    ///
    /// Centers bitmap in standard Playdate screen (400x240)
    ///
    /// Example:
    /// ```swift
    /// // Center on screen
    /// splashScreen.drawCenteredOnScreen()
    /// ```
    func drawCenteredOnScreen(flip: BitmapFlip = .unflipped) {
        drawCentered(at: Screen.columns / 2, Screen.rows / 2, flip: flip)
    }

    /// Draw bitmap in rectangle (top-left alignment)
    ///
    /// Draws bitmap at the top-left corner of the rectangle
    ///
    /// - Parameters:
    ///   - rect: Rectangle to draw in
    ///   - flip: Bitmap flip mode
    ///
    /// Example:
    /// ```swift
    /// let area = Rect(x: 50, y: 50, width: 100, height: 100)
    /// bitmap.draw(in: area)
    /// ```
    func draw(in rect: Rect, flip: BitmapFlip = .unflipped) {
        draw(at: rect.x, rect.y, flip: flip)
    }

    /// Draw bitmap centered in rectangle
    ///
    /// Centers bitmap within the given rectangle
    ///
    /// - Parameters:
    ///   - rect: Rectangle to center in
    ///   - flip: Bitmap flip mode
    ///
    /// Example:
    /// ```swift
    /// let box = Rect(x: 50, y: 50, width: 300, height: 140)
    /// bitmap.drawCentered(in: box)
    /// ```
    func drawCentered(in rect: Rect, flip: BitmapFlip = .unflipped) {
        let centerX = rect.x + (rect.width - width) / 2
        let centerY = rect.y + (rect.height - height) / 2
        draw(at: centerX, centerY, flip: flip)
    }
}

// MARK: - Scaled Drawing

public extension Bitmap {
    /// Draw bitmap scaled at specified position
    ///
    /// Draws the bitmap scaled by given factors.
    ///
    /// - Parameters:
    ///   - x: X coordinate for upper-left corner
    ///   - y: Y coordinate for upper-left corner
    ///   - xScale: Horizontal scale factor (negative values flip horizontally)
    ///   - yScale: Vertical scale factor (negative values flip vertically)
    ///
    /// From Playdate SDK:
    /// > "Draws the bitmap scaled to xscale and yscale with its upper-left
    /// > corner at location x, y. Note that flip is not available when drawing
    /// > scaled bitmaps but negative scale values will achieve the same effect."
    ///
    /// Example:
    /// ```swift
    /// // Draw double size
    /// bitmap.drawScaled(at: 100, 50, xScale: 2.0, yScale: 2.0)
    ///
    /// // Draw half size
    /// bitmap.drawScaled(at: 100, 50, xScale: 0.5, yScale: 0.5)
    ///
    /// // Draw flipped horizontally (negative scale)
    /// bitmap.drawScaled(at: 100, 50, xScale: -1.0, yScale: 1.0)
    ///
    /// // Draw stretched vertically
    /// bitmap.drawScaled(at: 100, 50, xScale: 1.0, yScale: 2.0)
    /// ```
    func drawScaled(
        at x: Int32,
        _ y: Int32,
        xScale: Float,
        yScale: Float
    ) {
        graphicsAPI.drawScaledBitmap(pointer, x, y, xScale, yScale)
    }

    /// Draw bitmap scaled at Point
    ///
    /// - Parameters:
    ///   - point: Position for upper-left corner
    ///   - xScale: Horizontal scale factor
    ///   - yScale: Vertical scale factor
    ///
    /// Example:
    /// ```swift
    /// let pos = Point(x: 100, y: 50)
    /// bitmap.drawScaled(at: pos, xScale: 2.0, yScale: 2.0)
    /// ```
    func drawScaled(
        at point: Point,
        xScale: Float,
        yScale: Float
    ) {
        drawScaled(at: point.x, point.y, xScale: xScale, yScale: yScale)
    }

    /// Draw bitmap scaled with Scale type
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - scale: Scale factors
    ///
    /// Example:
    /// ```swift
    /// bitmap.drawScaled(at: 100, 50, scale: .double)
    /// bitmap.drawScaled(at: 100, 50, scale: .flippedX)
    /// bitmap.drawScaled(at: 100, 50, scale: Scale(x: 2.0, y: 1.5))
    /// ```
    func drawScaled(at x: Int32, _ y: Int32, scale: Scale) {
        drawScaled(at: x, y, xScale: scale.x, yScale: scale.y)
    }

    /// Draw bitmap scaled with Scale at Point
    ///
    /// - Parameters:
    ///   - point: Position
    ///   - scale: Scale factors
    ///
    /// Example:
    /// ```swift
    /// bitmap.drawScaled(at: Point(x: 100, y: 50), scale: .double)
    /// ```
    func drawScaled(at point: Point, scale: Scale) {
        drawScaled(at: point.x, point.y, scale: scale)
    }

    /// Draw bitmap scaled uniformly
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - scale: Uniform scale factor
    ///
    /// Example:
    /// ```swift
    /// bitmap.drawScaled(at: 100, 50, scale: 2.0)  // Double size
    /// bitmap.drawScaled(at: 100, 50, scale: 0.5)  // Half size
    /// ```
    func drawScaled(at x: Int32, _ y: Int32, scale: Float) {
        drawScaled(at: x, y, xScale: scale, yScale: scale)
    }

    /// Draw bitmap scaled uniformly at Point
    ///
    /// - Parameters:
    ///   - point: Position
    ///   - scale: Uniform scale factor
    func drawScaled(at point: Point, scale: Float) {
        drawScaled(at: point, xScale: scale, yScale: scale)
    }

    /// Draw bitmap scaled to fit in rectangle
    ///
    /// Scales bitmap to fit within rectangle, maintaining aspect ratio
    ///
    /// - Parameters:
    ///   - rect: Target rectangle
    ///   - centered: Center in rectangle (default: true)
    ///
    /// Example:
    /// ```swift
    /// let box = Rect(x: 50, y: 50, width: 200, height: 150)
    /// bitmap.drawScaledToFit(in: box)
    /// ```
    func drawScaledToFit(in rect: Rect, centered: Bool = true) {
        // Calculate scale to fit
        let scaleX = Float(rect.width) / Float(width)
        let scaleY = Float(rect.height) / Float(height)
        let scale = min(scaleX, scaleY)

        if centered {
            // Center scaled bitmap in rect
            let scaledWidth = Float(width) * scale
            let scaledHeight = Float(height) * scale
            let offsetX = (Float(rect.width) - scaledWidth) / 2.0
            let offsetY = (Float(rect.height) - scaledHeight) / 2.0

            let x = rect.x + Int32(offsetX)
            let y = rect.y + Int32(offsetY)

            drawScaled(at: x, y, xScale: scale, yScale: scale)
        } else {
            drawScaled(at: rect.x, rect.y, xScale: scale, yScale: scale)
        }
    }

    /// Draw bitmap scaled to fill rectangle
    ///
    /// Scales bitmap to completely fill rectangle (may crop)
    ///
    /// - Parameters:
    ///   - rect: Target rectangle
    ///   - centered: Center in rectangle (default: true)
    ///
    /// Example:
    /// ```swift
    /// let box = Rect(x: 0, y: 0, width: 400, height: 240)
    /// background.drawScaledToFill(in: box)
    /// ```
    func drawScaledToFill(in rect: Rect, centered: Bool = true) {
        // Calculate scale to fill (uses max instead of min)
        let scaleX = Float(rect.width) / Float(width)
        let scaleY = Float(rect.height) / Float(height)
        let scale = max(scaleX, scaleY)

        if centered {
            let scaledWidth = Float(width) * scale
            let scaledHeight = Float(height) * scale
            let offsetX = (Float(rect.width) - scaledWidth) / 2.0
            let offsetY = (Float(rect.height) - scaledHeight) / 2.0

            let x = rect.x + Int32(offsetX)
            let y = rect.y + Int32(offsetY)

            drawScaled(at: x, y, xScale: scale, yScale: scale)
        } else {
            drawScaled(at: rect.x, rect.y, xScale: scale, yScale: scale)
        }
    }
}

// MARK: - Rotated Drawing

public extension Bitmap {
    /// Draw bitmap rotated and scaled at specified position
    ///
    /// Draws the bitmap rotated and scaled with center point specified
    /// as proportions of the bitmap's dimensions.
    ///
    /// - Parameters:
    ///   - x: X coordinate for center point
    ///   - y: Y coordinate for center point
    ///   - degrees: Rotation angle in degrees (clockwise)
    ///   - centerX: Center X proportion (0.0 = left, 0.5 = center, 1.0 = right)
    ///   - centerY: Center Y proportion (0.0 = top, 0.5 = center, 1.0 = bottom)
    ///   - xScale: Horizontal scale factor (default: 1.0)
    ///   - yScale: Vertical scale factor (default: 1.0)
    ///
    /// From Playdate SDK:
    /// > "Draws the bitmap scaled to xscale and yscale then rotated by degrees
    /// > with its center as given by proportions centerx and centery at x, y;
    /// > that is: if centerx and centery are both 0.5 the center of the image
    /// > is at (x,y), if centerx and centery are both 0 the top left corner of
    /// > the image (before rotation) is at (x,y), etc."
    ///
    /// Example:
    /// ```swift
    /// // Rotate around center
    /// bitmap.drawRotated(
    ///     at: 200, 120,
    ///     degrees: 45,
    ///     centerX: 0.5,
    ///     centerY: 0.5
    /// )
    ///
    /// // Rotate around top-left corner
    /// bitmap.drawRotated(
    ///     at: 200, 120,
    ///     degrees: 90,
    ///     centerX: 0.0,
    ///     centerY: 0.0
    /// )
    ///
    /// // Rotate and scale
    /// bitmap.drawRotated(
    ///     at: 200, 120,
    ///     degrees: 45,
    ///     centerX: 0.5,
    ///     centerY: 0.5,
    ///     xScale: 2.0,
    ///     yScale: 2.0
    /// )
    /// ```
    func drawRotated(
        at x: Int32,
        _ y: Int32,
        degrees: Float,
        centerX: Float = 0.5,
        centerY: Float = 0.5,
        xScale: Float = 1.0,
        yScale: Float = 1.0
    ) {
        graphicsAPI.drawRotatedBitmap(
            pointer,
            x,
            y,
            degrees,
            centerX,
            centerY,
            xScale,
            yScale
        )
    }

    /// Draw bitmap rotated at Point
    ///
    /// - Parameters:
    ///   - point: Position for center point
    ///   - degrees: Rotation angle in degrees
    ///   - centerX: Center X proportion (default: 0.5)
    ///   - centerY: Center Y proportion (default: 0.5)
    ///   - xScale: Horizontal scale (default: 1.0)
    ///   - yScale: Vertical scale (default: 1.0)
    ///
    /// Example:
    /// ```swift
    /// let pos = Point(x: 200, y: 120)
    /// bitmap.drawRotated(at: pos, degrees: 45)
    /// ```
    func drawRotated(
        at point: Point,
        degrees: Float,
        centerX: Float = 0.5,
        centerY: Float = 0.5,
        xScale: Float = 1.0,
        yScale: Float = 1.0
    ) {
        drawRotated(
            at: point.x,
            point.y,
            degrees: degrees,
            centerX: centerX,
            centerY: centerY,
            xScale: xScale,
            yScale: yScale
        )
    }

    /// Draw bitmap rotated with Rotation type
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - rotation: Rotation angle
    ///   - centerX: Center X proportion (default: 0.5)
    ///   - centerY: Center Y proportion (default: 0.5)
    ///   - xScale: Horizontal scale (default: 1.0)
    ///   - yScale: Vertical scale (default: 1.0)
    ///
    /// Example:
    /// ```swift
    /// bitmap.drawRotated(at: 200, 120, rotation: .clockwise90)
    /// bitmap.drawRotated(at: 200, 120, rotation: Rotation(degrees: 45))
    /// ```
    func drawRotated(
        at x: Int32,
        _ y: Int32,
        rotation: Rotation,
        centerX: Float = 0.5,
        centerY: Float = 0.5,
        xScale: Float = 1.0,
        yScale: Float = 1.0
    ) {
        drawRotated(
            at: x,
            y,
            degrees: rotation.degrees,
            centerX: centerX,
            centerY: centerY,
            xScale: xScale,
            yScale: yScale
        )
    }

    /// Draw bitmap rotated with RotationCenter type
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - degrees: Rotation angle in degrees
    ///   - center: Rotation center point
    ///   - xScale: Horizontal scale (default: 1.0)
    ///   - yScale: Vertical scale (default: 1.0)
    ///
    /// Example:
    /// ```swift
    /// bitmap.drawRotated(at: 200, 120, degrees: 45, center: .center)
    /// bitmap.drawRotated(at: 200, 120, degrees: 90, center: .topLeft)
    /// ```
    func drawRotated(
        at x: Int32,
        _ y: Int32,
        degrees: Float,
        center: RotationCenter,
        xScale: Float = 1.0,
        yScale: Float = 1.0
    ) {
        drawRotated(
            at: x,
            y,
            degrees: degrees,
            centerX: center.x,
            centerY: center.y,
            xScale: xScale,
            yScale: yScale
        )
    }

    /// Draw bitmap rotated with Rotation and RotationCenter
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - rotation: Rotation angle
    ///   - center: Rotation center
    ///   - xScale: Horizontal scale (default: 1.0)
    ///   - yScale: Vertical scale (default: 1.0)
    ///
    /// Example:
    /// ```swift
    /// bitmap.drawRotated(
    ///     at: 200, 120,
    ///     rotation: .clockwise90,
    ///     center: .center
    /// )
    /// ```
    func drawRotated(
        at x: Int32,
        _ y: Int32,
        rotation: Rotation,
        center: RotationCenter,
        xScale: Float = 1.0,
        yScale: Float = 1.0
    ) {
        drawRotated(
            at: x,
            y,
            degrees: rotation.degrees,
            centerX: center.x,
            centerY: center.y,
            xScale: xScale,
            yScale: yScale
        )
    }

    /// Draw bitmap rotated at Point with RotationCenter
    ///
    /// - Parameters:
    ///   - point: Position
    ///   - degrees: Rotation angle
    ///   - center: Rotation center
    ///   - xScale: Horizontal scale (default: 1.0)
    ///   - yScale: Vertical scale (default: 1.0)
    func drawRotated(
        at point: Point,
        degrees: Float,
        center: RotationCenter,
        xScale: Float = 1.0,
        yScale: Float = 1.0
    ) {
        drawRotated(
            at: point.x,
            point.y,
            degrees: degrees,
            center: center,
            xScale: xScale,
            yScale: yScale
        )
    }

    /// Draw bitmap rotated at Point with Rotation and RotationCenter
    ///
    /// - Parameters:
    ///   - point: Position
    ///   - rotation: Rotation angle
    ///   - center: Rotation center
    ///   - xScale: Horizontal scale (default: 1.0)
    ///   - yScale: Vertical scale (default: 1.0)
    func drawRotated(
        at point: Point,
        rotation: Rotation,
        center: RotationCenter,
        xScale: Float = 1.0,
        yScale: Float = 1.0
    ) {
        drawRotated(
            at: point,
            degrees: rotation.degrees,
            center: center,
            xScale: xScale,
            yScale: yScale
        )
    }

    /// Draw bitmap rotated with Scale type
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - degrees: Rotation angle
    ///   - center: Rotation center (default: .center)
    ///   - scale: Scale factors
    ///
    /// Example:
    /// ```swift
    /// bitmap.drawRotated(at: 200, 120, degrees: 45, scale: .double)
    /// bitmap.drawRotated(at: 200, 120, degrees: 90, scale: Scale(x: 2, y: 1))
    /// ```
    func drawRotated(
        at x: Int32,
        _ y: Int32,
        degrees: Float,
        center: RotationCenter = .center,
        scale: Scale
    ) {
        drawRotated(
            at: x,
            y,
            degrees: degrees,
            centerX: center.x,
            centerY: center.y,
            xScale: scale.x,
            yScale: scale.y
        )
    }

    /// Draw bitmap rotated with Rotation and Scale
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - rotation: Rotation angle
    ///   - center: Rotation center (default: .center)
    ///   - scale: Scale factors
    func drawRotated(
        at x: Int32,
        _ y: Int32,
        rotation: Rotation,
        center: RotationCenter = .center,
        scale: Scale
    ) {
        drawRotated(
            at: x,
            y,
            degrees: rotation.degrees,
            center: center,
            scale: scale
        )
    }

    /// Draw bitmap rotated at Point with Scale
    ///
    /// - Parameters:
    ///   - point: Position
    ///   - rotation: Rotation angle
    ///   - center: Rotation center (default: .center)
    ///   - scale: Scale factors
    func drawRotated(
        at point: Point,
        rotation: Rotation,
        center: RotationCenter = .center,
        scale: Scale
    ) {
        drawRotated(
            at: point.x,
            point.y,
            rotation: rotation,
            center: center,
            scale: scale
        )
    }

    /// Draw bitmap rotated around its center (convenience)
    ///
    /// Always rotates around center (0.5, 0.5)
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - degrees: Rotation angle
    ///   - xScale: Horizontal scale (default: 1.0)
    ///   - yScale: Vertical scale (default: 1.0)
    ///
    /// Example:
    /// ```swift
    /// bitmap.drawRotatedCentered(at: 200, 120, degrees: 45)
    /// ```
    func drawRotatedCentered(
        at x: Int32,
        _ y: Int32,
        degrees: Float,
        xScale: Float = 1.0,
        yScale: Float = 1.0
    ) {
        drawRotated(
            at: x,
            y,
            degrees: degrees,
            centerX: 0.5,
            centerY: 0.5,
            xScale: xScale,
            yScale: yScale
        )
    }

    /// Draw bitmap rotated around center at Point
    ///
    /// - Parameters:
    ///   - point: Position
    ///   - degrees: Rotation angle
    ///   - xScale: Horizontal scale (default: 1.0)
    ///   - yScale: Vertical scale (default: 1.0)
    func drawRotatedCentered(
        at point: Point,
        degrees: Float,
        xScale: Float = 1.0,
        yScale: Float = 1.0
    ) {
        drawRotatedCentered(
            at: point.x,
            point.y,
            degrees: degrees,
            xScale: xScale,
            yScale: yScale
        )
    }

    /// Draw bitmap rotated around center with Rotation
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - rotation: Rotation angle
    ///   - xScale: Horizontal scale (default: 1.0)
    ///   - yScale: Vertical scale (default: 1.0)
    func drawRotatedCentered(
        at x: Int32,
        _ y: Int32,
        rotation: Rotation,
        xScale: Float = 1.0,
        yScale: Float = 1.0
    ) {
        drawRotatedCentered(
            at: x,
            y,
            degrees: rotation.degrees,
            xScale: xScale,
            yScale: yScale
        )
    }

    /// Draw bitmap rotated around center at Point with Rotation
    ///
    /// - Parameters:
    ///   - point: Position
    ///   - rotation: Rotation angle
    ///   - xScale: Horizontal scale (default: 1.0)
    ///   - yScale: Vertical scale (default: 1.0)
    func drawRotatedCentered(
        at point: Point,
        rotation: Rotation,
        xScale: Float = 1.0,
        yScale: Float = 1.0
    ) {
        drawRotatedCentered(
            at: point,
            degrees: rotation.degrees,
            xScale: xScale,
            yScale: yScale
        )
    }

    /// Draw bitmap rotated around center with Scale
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - rotation: Rotation angle
    ///   - scale: Scale factors
    func drawRotatedCentered(
        at x: Int32,
        _ y: Int32,
        rotation: Rotation,
        scale: Scale
    ) {
        drawRotatedCentered(
            at: x,
            y,
            degrees: rotation.degrees,
            xScale: scale.x,
            yScale: scale.y
        )
    }

    /// Draw bitmap rotated around center at Point with Scale
    ///
    /// - Parameters:
    ///   - point: Position
    ///   - rotation: Rotation angle
    ///   - scale: Scale factors
    func drawRotatedCentered(
        at point: Point,
        rotation: Rotation,
        scale: Scale
    ) {
        drawRotatedCentered(
            at: point.x,
            point.y,
            rotation: rotation,
            scale: scale
        )
    }
}

// MARK: - Tiled Drawing

public extension Bitmap {
    /// Draw bitmap tiled in a rectangular area
    ///
    /// Repeats the bitmap to fill the specified rectangle.
    ///
    /// - Parameters:
    ///   - x: X coordinate of rectangle
    ///   - y: Y coordinate of rectangle
    ///   - width: Width of tile area
    ///   - height: Height of tile area
    ///   - flip: Bitmap flip mode (default: unflipped)
    ///
    /// From Playdate SDK:
    /// > "Draws the bitmap with its upper-left corner at location x, y
    /// > tiled inside a width by height rectangle."
    ///
    /// Example:
    /// ```swift
    /// // Tile background pattern
    /// let pattern = Bitmap.load("tile-pattern").get()
    /// pattern.drawTiled(at: 0, 0, width: 400, height: 240)
    ///
    /// // Tile with flip
    /// pattern.drawTiled(
    ///     at: 0, 0,
    ///     width: 400, height: 240,
    ///     flip: .flippedX
    /// )
    /// ```
    func drawTiled(
        at x: Int32,
        _ y: Int32,
        width: Int32,
        height: Int32,
        flip: BitmapFlip = .unflipped
    ) {
        graphicsAPI.tileBitmap(pointer, x, y, width, height, flip.cValue)
    }

    /// Draw bitmap tiled in Rect
    ///
    /// - Parameters:
    ///   - rect: Rectangle to tile in
    ///   - flip: Bitmap flip mode (default: unflipped)
    ///
    /// Example:
    /// ```swift
    /// let area = Rect(x: 0, y: 0, width: 400, height: 240)
    /// pattern.drawTiled(in: area)
    /// ```
    func drawTiled(in rect: Rect, flip: BitmapFlip = .unflipped) {
        drawTiled(
            at: rect.x,
            rect.y,
            width: rect.width,
            height: rect.height,
            flip: flip
        )
    }

    /// Draw bitmap tiled at Point with Size
    ///
    /// - Parameters:
    ///   - point: Top-left position
    ///   - size: Size of tile area
    ///   - flip: Bitmap flip mode (default: unflipped)
    ///
    /// Example:
    /// ```swift
    /// let pos = Point(x: 0, y: 0)
    /// let size = Size(width: 400, height: 240)
    /// pattern.drawTiled(at: pos, size: size)
    /// ```
    func drawTiled(
        at point: Point,
        size: Size,
        flip: BitmapFlip = .unflipped
    ) {
        drawTiled(
            at: point.x,
            point.y,
            width: size.width,
            height: size.height,
            flip: flip
        )
    }

    /// Draw bitmap tiled to fill entire screen
    ///
    /// Tiles bitmap across the full Playdate screen (400x240)
    ///
    /// - Parameter flip: Bitmap flip mode (default: unflipped)
    ///
    /// Example:
    /// ```swift
    /// // Fill screen with tiled pattern
    /// backgroundPattern.drawTiledFullScreen()
    /// ```
    func drawTiledFullScreen(flip: BitmapFlip = .unflipped) {
        drawTiled(in: Screen.rect, flip: flip)
    }

    /// Draw bitmap tiled horizontally
    ///
    /// Tiles bitmap horizontally across specified width
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - width: Width to tile across
    ///   - flip: Bitmap flip mode (default: unflipped)
    ///
    /// Example:
    /// ```swift
    /// // Tile horizontally across screen
    /// border.drawTiledHorizontally(at: 0, 100, width: 400)
    /// ```
    func drawTiledHorizontally(
        at x: Int32,
        _ y: Int32,
        width: Int32,
        flip: BitmapFlip = .unflipped
    ) {
        drawTiled(at: x, y, width: width, height: height, flip: flip)
    }

    /// Draw bitmap tiled vertically
    ///
    /// Tiles bitmap vertically across specified height
    ///
    /// - Parameters:
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - height: Height to tile across
    ///   - flip: Bitmap flip mode (default: unflipped)
    ///
    /// Example:
    /// ```swift
    /// // Tile vertically down screen
    /// border.drawTiledVertically(at: 50, 0, height: 240)
    /// ```
    func drawTiledVertically(
        at x: Int32,
        _ y: Int32,
        height: Int32,
        flip: BitmapFlip = .unflipped
    ) {
        drawTiled(at: x, y, width: width, height: height, flip: flip)
    }
}

// MARK: - Collision Detection

public extension Bitmap {
    /// Check if this bitmap's mask collides with another bitmap's mask
    ///
    /// Tests if any opaque pixels overlap when bitmaps are positioned
    /// at given coordinates within the specified rectangle.
    ///
    /// - Parameters:
    ///   - other: Other bitmap to check collision with
    ///   - x1: X coordinate of this bitmap
    ///   - y1: Y coordinate of this bitmap
    ///   - flip1: Flip mode for this bitmap (default: unflipped)
    ///   - x2: X coordinate of other bitmap
    ///   - y2: Y coordinate of other bitmap
    ///   - flip2: Flip mode for other bitmap (default: unflipped)
    ///   - rect: Bounding rectangle to check within
    /// - Returns: true if bitmaps collide, false otherwise
    ///
    /// From Playdate SDK:
    /// > "Returns 1 if any of the opaque pixels in bitmap1 when positioned at
    /// > x1, y1 with flip1 overlap any of the opaque pixels in bitmap2 at
    /// > x2, y2 with flip2 within the non-empty rect, or 0 if no pixels
    /// > overlap or if one or both fall completely outside of rect."
    ///
    /// Example:
    /// ```swift
    /// let player = Bitmap.load("player").get()
    /// let enemy = Bitmap.load("enemy").get()
    ///
    /// if player.checkMaskCollision(
    ///     with: enemy,
    ///     at: 100, 50,
    ///     flip1: .unflipped,
    ///     otherAt: 150, 60,
    ///     flip2: .unflipped,
    ///     in: Screen.rect
    /// ) {
    ///     print("Collision detected!")
    /// }
    /// ```
    func checkMaskCollision(
        with other: Bitmap,
        at x1: Int32,
        _ y1: Int32,
        flip1: BitmapFlip = .unflipped,
        otherAt x2: Int32,
        _ y2: Int32,
        flip2: BitmapFlip = .unflipped,
        in rect: Rect
    ) -> Bool {
        let result = graphicsAPI.checkMaskCollision(
            pointer,
            x1,
            y1,
            flip1.cValue,
            other.pointer,
            x2,
            y2,
            flip2.cValue,
            rect.cValue
        )
        return result != 0
    }

    /// Check collision using Point positions
    ///
    /// - Parameters:
    ///   - other: Other bitmap
    ///   - position1: Position of this bitmap
    ///   - flip1: Flip mode for this bitmap (default: unflipped)
    ///   - position2: Position of other bitmap
    ///   - flip2: Flip mode for other bitmap (default: unflipped)
    ///   - rect: Bounding rectangle
    /// - Returns: true if collision detected
    ///
    /// Example:
    /// ```swift
    /// if player.checkMaskCollision(
    ///     with: enemy,
    ///     at: Point(x: 100, y: 50),
    ///     otherAt: Point(x: 150, y: 60),
    ///     in: Screen.rect
    /// ) {
    ///     print("Hit!")
    /// }
    /// ```
    func checkMaskCollision(
        with other: Bitmap,
        at position1: Point,
        flip1: BitmapFlip = .unflipped,
        otherAt position2: Point,
        flip2: BitmapFlip = .unflipped,
        in rect: Rect
    ) -> Bool {
        return checkMaskCollision(
            with: other,
            at: position1.x,
            position1.y,
            flip1: flip1,
            otherAt: position2.x,
            position2.y,
            flip2: flip2,
            in: rect
        )
    }

    /// Check collision within screen bounds
    ///
    /// Convenience method that uses full screen as bounding rectangle
    ///
    /// - Parameters:
    ///   - other: Other bitmap
    ///   - x1: X coordinate of this bitmap
    ///   - y1: Y coordinate of this bitmap
    ///   - flip1: Flip mode for this bitmap (default: unflipped)
    ///   - x2: X coordinate of other bitmap
    ///   - y2: Y coordinate of other bitmap
    ///   - flip2: Flip mode for other bitmap (default: unflipped)
    /// - Returns: true if collision detected
    ///
    /// Example:
    /// ```swift
    /// if player.checkMaskCollisionOnScreen(
    ///     with: enemy,
    ///     at: 100, 50,
    ///     otherAt: 150, 60
    /// ) {
    ///     print("Collision!")
    /// }
    /// ```
    func checkMaskCollisionOnScreen(
        with other: Bitmap,
        at x1: Int32,
        _ y1: Int32,
        flip1: BitmapFlip = .unflipped,
        otherAt x2: Int32,
        _ y2: Int32,
        flip2: BitmapFlip = .unflipped
    ) -> Bool {
        return checkMaskCollision(
            with: other,
            at: x1,
            y1,
            flip1: flip1,
            otherAt: x2,
            y2,
            flip2: flip2,
            in: Screen.rect
        )
    }

    /// Check collision on screen using Points
    ///
    /// - Parameters:
    ///   - other: Other bitmap
    ///   - position1: Position of this bitmap
    ///   - flip1: Flip mode for this bitmap (default: unflipped)
    ///   - position2: Position of other bitmap
    ///   - flip2: Flip mode for other bitmap (default: unflipped)
    /// - Returns: true if collision detected
    func checkMaskCollisionOnScreen(
        with other: Bitmap,
        at position1: Point,
        flip1: BitmapFlip = .unflipped,
        otherAt position2: Point,
        flip2: BitmapFlip = .unflipped
    ) -> Bool {
        return checkMaskCollision(
            with: other,
            at: position1,
            flip1: flip1,
            otherAt: position2,
            flip2: flip2,
            in: Screen.rect
        )
    }

    /// Check if bitmaps collide when both are unflipped
    ///
    /// Simplified collision check for most common case
    ///
    /// - Parameters:
    ///   - other: Other bitmap
    ///   - x1: X coordinate of this bitmap
    ///   - y1: Y coordinate of this bitmap
    ///   - x2: X coordinate of other bitmap
    ///   - y2: Y coordinate of other bitmap
    ///   - rect: Bounding rectangle
    /// - Returns: true if collision detected
    ///
    /// Example:
    /// ```swift
    /// if player.collidesWith(
    ///     enemy,
    ///     at: 100, 50,
    ///     otherAt: 150, 60,
    ///     in: Screen.rect
    /// ) {
    ///     handleCollision()
    /// }
    /// ```
    func collidesWith(
        _ other: Bitmap,
        at x1: Int32,
        _ y1: Int32,
        otherAt x2: Int32,
        _ y2: Int32,
        in rect: Rect
    ) -> Bool {
        return checkMaskCollision(
            with: other,
            at: x1,
            y1,
            flip1: .unflipped,
            otherAt: x2,
            y2,
            flip2: .unflipped,
            in: rect
        )
    }

    /// Check collision with Points, unflipped
    ///
    /// - Parameters:
    ///   - other: Other bitmap
    ///   - position1: Position of this bitmap
    ///   - position2: Position of other bitmap
    ///   - rect: Bounding rectangle
    /// - Returns: true if collision detected
    func collidesWith(
        _ other: Bitmap,
        at position1: Point,
        otherAt position2: Point,
        in rect: Rect
    ) -> Bool {
        return checkMaskCollision(
            with: other,
            at: position1,
            flip1: .unflipped,
            otherAt: position2,
            flip2: .unflipped,
            in: rect
        )
    }

    /// Check collision on screen, unflipped
    ///
    /// Most simplified collision check for common cases
    ///
    /// - Parameters:
    ///   - other: Other bitmap
    ///   - x1: X coordinate of this bitmap
    ///   - y1: Y coordinate of this bitmap
    ///   - x2: X coordinate of other bitmap
    ///   - y2: Y coordinate of other bitmap
    /// - Returns: true if collision detected
    func collidesOnScreen(
        with other: Bitmap,
        at x1: Int32,
        _ y1: Int32,
        otherAt x2: Int32,
        _ y2: Int32
    ) -> Bool {
        return checkMaskCollisionOnScreen(
            with: other,
            at: x1,
            y1,
            flip1: .unflipped,
            otherAt: x2,
            y2,
            flip2: .unflipped
        )
    }

    /// Check collision on screen with Points, unflipped
    ///
    /// - Parameters:
    ///   - other: Other bitmap
    ///   - position1: Position of this bitmap
    ///   - position2: Position of other bitmap
    /// - Returns: true if collision detected
    ///
    /// Example:
    /// ```swift
    /// let playerPos = Point(x: 100, y: 50)
    /// let enemyPos = Point(x: 150, y: 60)
    ///
    /// if player.collidesOnScreen(with: enemy, at: playerPos, otherAt: enemyPos) {
    ///     print("Hit!")
    /// }
    /// ```
    func collidesOnScreen(
        with other: Bitmap,
        at position1: Point,
        otherAt position2: Point
    ) -> Bool {
        return checkMaskCollisionOnScreen(
            with: other,
            at: position1,
            flip1: .unflipped,
            otherAt: position2,
            flip2: .unflipped
        )
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
                reason: "Failed to rotate bitmap by \(rotation.string)°"
            )
        }

        return Bitmap(ownedPointer: ptr, sourcePath)
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
