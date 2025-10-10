//
// Types.swift
// Playdate Graphics SDK
//
// Centralized types, constants, and Swift wrappers for the C API
//

// MARK: - Screen Constants

/// Screen Constants Playdate
public enum Screen {
    public static let columns: Int32 = 400
    public static let rows: Int32 = 240
    public static let rowSize: Int32 = 52

    /// Whole screen Rect
    public static let rect = Rect(x: 0, y: 0, width: columns, height: rows)
}

// MARK: - Geometric Types

/// Swift wrapper for LCDRect, compatible with C API
public struct Rect: Sendable {
    public let left: Int32
    public let right: Int32 // not inclusive
    public let top: Int32
    public let bottom: Int32 // not inclusive

    public init(x: Int32, y: Int32, width: Int32, height: Int32) {
        // Assume that width and height are positive
        left = x
        right = x + width
        top = y
        bottom = y + height
    }

    public init(left: Int32, top: Int32, right: Int32, bottom: Int32) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    public var width: Int32 { right - left }

    public var height: Int32 { bottom - top }

    /// X coordinate of the left part
    public var x: Int32 { left }

    /// Y coordinate of the top part
    public var y: Int32 { top }

    public func translated(by dx: Int32, _ dy: Int32) -> Rect {
        return Rect(left: left + dx, top: top + dy, right: right + dx, bottom: bottom + dy)
    }

    /// Convert to C API LCDRect structure
    ///
    /// Creates LCDRect compatible with Playdate C API
    ///
    /// Example:
    /// ```swift
    /// let rect = Rect(x: 10, y: 20, width: 100, height: 50)
    /// let cRect = rect.cValue  // LCDRect for C API
    /// ```
    var cValue: LCDRect {
        return LCDRect(
            left: left,
            right: right,
            top: top,
            bottom: bottom
        )
    }
}

/// 2D Point
public struct Point: Sendable {
    public let x: Int32
    public let y: Int32

    public init(x: Int32, y: Int32) {
        self.x = x
        self.y = y
    }

    public func translated(by dx: Int32, _ dy: Int32) -> Point {
        return Point(x: x + dx, y: y + dy)
    }
}

public struct Size: Sendable {
    public let width: Int32
    public let height: Int32

    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
    }
}

// MARK: - Drawing Modes and Flips

/// Bitmap drawing modes - Swift wrapper for LCDBitmapDrawMode
public enum BitmapDrawMode: UInt32 {
    case copy = 0
    case whiteTransparent = 1
    case blackTransparent = 2
    case fillWhite = 3
    case fillBlack = 4
    case xor = 5
    case nxor = 6
    case inverted = 7

    /// Conversion to C enum value
    ///
    /// Uses explicit C constants to avoid type ambiguity
    public var cValue: LCDBitmapDrawMode {
        switch self {
        case .copy:
            return LCDBitmapDrawMode.drawModeCopy
        case .whiteTransparent:
            return LCDBitmapDrawMode.drawModeWhiteTransparent
        case .blackTransparent:
            return LCDBitmapDrawMode.drawModeBlackTransparent
        case .fillWhite:
            return LCDBitmapDrawMode.drawModeFillWhite
        case .fillBlack:
            return LCDBitmapDrawMode.drawModeFillBlack
        case .xor:
            return LCDBitmapDrawMode.drawModeXOR
        case .nxor:
            return LCDBitmapDrawMode.drawModeNXOR
        case .inverted:
            return LCDBitmapDrawMode.drawModeInverted
        }
    }
}

/// Bitmap Reflection modes - Swift wrapper for LCDBitmapFlip
public enum BitmapFlip: UInt32, Sendable {
    case none = 0
    case x = 1
    case y = 2
    case xy = 3

    /// Conversion to C enum value
    ///
    /// Uses explicit C constants to avoid type ambiguity
    public var cValue: LCDBitmapFlip {
        switch self {
        case .none:
            return LCDBitmapFlip.bitmapUnflipped
        case .x:
            return LCDBitmapFlip.bitmapFlippedX
        case .y:
            return LCDBitmapFlip.bitmapFlippedY
        case .xy:
            return LCDBitmapFlip.bitmapFlippedXY
        }
    }
}

// MARK: - Colors and Patterns

/// Solid Colors - Swift wrapper for LCDSolidColor
public enum SolidColor: UInt32, Sendable {
    case black = 0
    case white = 1
    case clear = 2
    case xor = 3

    /// Conversion to C enum value
    public var cValue: LCDSolidColor {
        switch self {
        case .black: return LCDSolidColor.colorBlack
        case .white: return LCDSolidColor.colorWhite
        case .clear: return LCDSolidColor.colorClear
        case .xor: return LCDSolidColor.colorXOR
        }
    }

    public var colorValue: LCDColor {
        return LCDColor(rawValue)
    }
}

/// An 8x8 pixel fill pattern
/// Swift wrapper for LCDPattern (16 bytes: 8 bytes of image + 8 bytes of mask)
public struct Pattern: Sendable {
    public let bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                       UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    /// Creating a pattern with 8 image lines (the mask will be 0xFF for opacity)
    public init(rows r0: UInt8, _ r1: UInt8, _ r2: UInt8, _ r3: UInt8,
                _ r4: UInt8, _ r5: UInt8, _ r6: UInt8, _ r7: UInt8)
    {
        bytes = (r0, r1, r2, r3, r4, r5, r6, r7,
                 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF)
    }

    /// Creating a pattern with an image and a mask
    public init(imageRows: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
                maskRows: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8))
    {
        bytes = (imageRows.0, imageRows.1, imageRows.2, imageRows.3,
                 imageRows.4, imageRows.5, imageRows.6, imageRows.7,
                 maskRows.0, maskRows.1, maskRows.2, maskRows.3,
                 maskRows.4, maskRows.5, maskRows.6, maskRows.7)
    }

    /// Conversion to LCDColor (pointer value)
    /// - Warning: Pattern must remain alive while this value is used.
    ///           Store patterns as constants or instance variables.
    public var colorValue: LCDColor {
        return withUnsafeBytes(of: bytes) { buffer in
            LCDColor(UInt(bitPattern: buffer.baseAddress))
        }
    }
}

/// The color for drawing can be a solid color or a pattern.
/// Swift wrapper for LCDColor (uintptr_t)
public enum Color: Sendable {
    case solid(SolidColor)
    case pattern(Pattern)

    /// Frequently used colors as static properties
    public static let black = Color.solid(.black)
    public static let white = Color.solid(.white)
    public static let clear = Color.solid(.clear)
    public static let xor = Color.solid(.xor)

    public var cValue: LCDColor {
        return switch self {
        case let .solid(solidColor):
            solidColor.colorValue
        case let .pattern(pattern):
            pattern.colorValue
        }
    }
}

// MARK: - Line and Font Settings

/// Line Endings style - Swift wrapper for LCDLineCapStyle
public enum LineCapStyle: UInt32 {
    case butt = 0
    case square = 1
    case round = 2

    /// Conversion to C enum value
    ///
    /// Uses explicit C constants to avoid type ambiguity
    public var cValue: LCDLineCapStyle {
        switch self {
        case .butt:
            return LCDLineCapStyle.lineCapStyleButt
        case .square:
            return LCDLineCapStyle.lineCapStyleSquare
        case .round:
            return LCDLineCapStyle.lineCapStyleRound
        }
    }
}

/// Font Languages - Swift wrapper for LCDFontLanguage
public enum FontLanguage: UInt32 {
    case english = 0
    case japanese = 1
    case unknown = 2

    /// Conversion to C enum value
    ///
    /// Uses explicit C constants to avoid type ambiguity
    public var cValue: LCDFontLanguage {
        switch self {
        case .english:
            return LCDFontLanguage.english
        case .japanese:
            return LCDFontLanguage.japanese
        case .unknown:
            return LCDFontLanguage.unknown
        }
    }
}

/// String Encodings - Swift wrapper for PDStringEncoding
public enum StringEncoding: UInt32 {
    case ascii = 0
    case utf8 = 1
    case utf16LE = 2

    /// Conversion to C enum value
    ///
    /// Uses explicit C constants to avoid type ambiguity
    public var cValue: PDStringEncoding {
        switch self {
        case .ascii:
            return PDStringEncoding.kASCIIEncoding
        case .utf8:
            return PDStringEncoding.kUTF8Encoding
        case .utf16LE:
            return PDStringEncoding.k16BitLEEncoding
        }
    }
}

// MARK: - Polygon and Text Settings

/// Polygon filling rules - Swift wrapper for LCDPolygonFillRule
public enum PolygonFillRule: UInt32 {
    case nonZero = 0
    case evenOdd = 1

    /// Conversion to C enum value
    ///
    /// Uses explicit C constants to avoid type ambiguity
    public var cValue: LCDPolygonFillRule {
        switch self {
        case .nonZero:
            return kPolygonFillNonZero
        case .evenOdd:
            return kPolygonFillEvenOdd
        }
    }
}

/// Text wrapping Modes - Swift wrapper for PDTextWrappingMode
public enum TextWrappingMode: UInt32 {
    case clip = 0
    case character = 1
    case word = 2

    /// Conversion to C enum value
    ///
    /// Uses explicit C constants to avoid type ambiguity
    public var cValue: PDTextWrappingMode {
        switch self {
        case .clip:
            return PDTextWrappingMode.wrapClip
        case .character:
            return PDTextWrappingMode.wrapCharacter
        case .word:
            return PDTextWrappingMode.wrapWord
        }
    }
}

/// Text Alignment - Swift wrapper for PDTextAlignment
public enum TextAlignment: UInt32 {
    case left = 0
    case center = 1
    case right = 2

    /// Conversion to C enum value
    ///
    /// Uses explicit C constants to avoid type ambiguity
    public var cValue: PDTextAlignment {
        switch self {
        case .left:
            return PDTextAlignment.alignTextLeft
        case .center:
            return PDTextAlignment.alignTextCenter
        case .right:
            return PDTextAlignment.alignTextRight
        }
    }
}

// MARK: - Extensions

public extension Point {
    /// Zero Point
    static let zero = Point(x: 0, y: 0)
}

public extension Size {
    /// Zero Size
    static let zero = Size(width: 0, height: 0)
}

public extension Rect {
    /// Zero Rect
    static let zero = Rect(x: 0, y: 0, width: 0, height: 0)

    /// Checking if the rectangle is empty
    var isEmpty: Bool {
        return width <= 0 || height <= 0
    }
}

// MARK: - Bitmap Flip Extensions

public extension BitmapFlip {
    /// Unflipped bitmap (normal orientation)
    static let unflipped = BitmapFlip.none

    /// Flipped horizontally
    static let flippedX = BitmapFlip.x

    /// Flipped vertically
    static let flippedY = BitmapFlip.y

    /// Flipped both horizontally and vertically
    static let flippedXY = BitmapFlip.xy

    /// Check if bitmap is flipped horizontally
    var isFlippedHorizontally: Bool {
        return self == .x || self == .xy
    }

    /// Check if bitmap is flipped vertically
    var isFlippedVertically: Bool {
        return self == .y || self == .xy
    }

    /// Combine with another flip
    func combined(with other: BitmapFlip) -> BitmapFlip {
        let combined = rawValue ^ other.rawValue
        return BitmapFlip(rawValue: combined) ?? .none
    }
}

// MARK: - Scale Type

/// Scale factors for bitmap transformations
public struct Scale: Sendable {
    public let x: Float
    public let y: Float

    /// Create scale with separate X and Y factors
    ///
    /// - Parameters:
    ///   - x: Horizontal scale factor (negative values flip horizontally)
    ///   - y: Vertical scale factor (negative values flip vertically)
    ///
    /// Example:
    /// ```swift
    /// let scale = Scale(x: 2.0, y: 2.0)    // Double size
    /// let scale = Scale(x: 0.5, y: 0.5)    // Half size
    /// let scale = Scale(x: -1.0, y: 1.0)   // Flipped horizontally
    /// ```
    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    /// Create uniform scale
    ///
    /// - Parameter uniform: Scale factor for both axes
    ///
    /// Example:
    /// ```swift
    /// let scale = Scale(uniform: 2.0)  // 2x in both directions
    /// ```
    public init(uniform: Float) {
        x = uniform
        y = uniform
    }

    /// No scaling (1.0, 1.0)
    public static let none = Scale(x: 1.0, y: 1.0)

    /// Double size (2.0, 2.0)
    public static let double = Scale(x: 2.0, y: 2.0)

    /// Half size (0.5, 0.5)
    public static let half = Scale(x: 0.5, y: 0.5)

    /// Flipped horizontally (-1.0, 1.0)
    public static let flippedX = Scale(x: -1.0, y: 1.0)

    /// Flipped vertically (1.0, -1.0)
    public static let flippedY = Scale(x: 1.0, y: -1.0)

    /// Flipped both ways (-1.0, -1.0)
    public static let flippedXY = Scale(x: -1.0, y: -1.0)

    /// Check if scale represents horizontal flip
    public var isFlippedX: Bool {
        return x < 0
    }

    /// Check if scale represents vertical flip
    public var isFlippedY: Bool {
        return y < 0
    }

    /// Check if this is uniform scaling
    public var isUniform: Bool {
        return abs(x - y) < 0.001
    }

    /// Create scale from BitmapFlip
    public init(from flip: BitmapFlip) {
        switch flip {
        case .none:
            self = .none
        case .x:
            self = .flippedX
        case .y:
            self = .flippedY
        case .xy:
            self = .flippedXY
        }
    }
}

// MARK: - Rotation Center

/// Center point for rotation (proportional coordinates 0.0 to 1.0)
public struct RotationCenter: Sendable {
    public let x: Float
    public let y: Float

    /// Create rotation center with proportional coordinates
    ///
    /// - Parameters:
    ///   - x: Horizontal proportion (0.0 = left edge, 0.5 = center, 1.0 = right edge)
    ///   - y: Vertical proportion (0.0 = top edge, 0.5 = center, 1.0 = bottom edge)
    ///
    /// From Playdate SDK:
    /// > "if centerx and centery are both 0.5 the center of the image is at (x,y),
    /// > if centerx and centery are both 0 the top left corner of the image
    /// > (before rotation) is at (x,y)"
    ///
    /// Example:
    /// ```swift
    /// let center = RotationCenter(x: 0.5, y: 0.5)  // Center of image
    /// let topLeft = RotationCenter(x: 0.0, y: 0.0) // Top-left corner
    /// ```
    public init(x: Float, y: Float) {
        // Clamp to valid range
        self.x = min(max(x, 0.0), 1.0)
        self.y = min(max(y, 0.0), 1.0)
    }

    /// Center of image (0.5, 0.5)
    public static let center = RotationCenter(x: 0.5, y: 0.5)

    /// Top-left corner (0.0, 0.0)
    public static let topLeft = RotationCenter(x: 0.0, y: 0.0)

    /// Top-right corner (1.0, 0.0)
    public static let topRight = RotationCenter(x: 1.0, y: 0.0)

    /// Bottom-left corner (0.0, 1.0)
    public static let bottomLeft = RotationCenter(x: 0.0, y: 1.0)

    /// Bottom-right corner (1.0, 1.0)
    public static let bottomRight = RotationCenter(x: 1.0, y: 1.0)

    /// Top-center (0.5, 0.0)
    public static let topCenter = RotationCenter(x: 0.5, y: 0.0)

    /// Bottom-center (0.5, 1.0)
    public static let bottomCenter = RotationCenter(x: 0.5, y: 1.0)

    /// Left-center (0.0, 0.5)
    public static let leftCenter = RotationCenter(x: 0.0, y: 0.5)

    /// Right-center (1.0, 0.5)
    public static let rightCenter = RotationCenter(x: 1.0, y: 0.5)
}

// MARK: - Rotation Angle

/// Rotation angle helper
public struct Rotation: Sendable {
    public let degrees: Float

    /// Create rotation from degrees
    public init(degrees: Float) {
        self.degrees = degrees
    }

    /// Create rotation from radians
    public init(radians: Float) {
        degrees = radians * 180.0 / Float.pi
    }

    /// No rotation (0°)
    public static let none = Rotation(degrees: 0)

    /// 90 degrees clockwise
    public static let clockwise90 = Rotation(degrees: 90)

    /// 180 degrees
    public static let flip180 = Rotation(degrees: 180)

    /// 270 degrees clockwise (or 90 counter-clockwise)
    public static let clockwise270 = Rotation(degrees: 270)

    /// Convert to radians
    public var radians: Float {
        return degrees * Float.pi / 180.0
    }

    /// Normalize angle to 0...360 range
    public var normalized: Rotation {
        var normalized = degrees.truncatingRemainder(dividingBy: 360)
        if normalized < 0 {
            normalized += 360
        }
        return Rotation(degrees: normalized)
    }
}

// MARK: - Convenience Extensions

public extension Scale {
    /// Multiply scales
    static func * (lhs: Scale, rhs: Scale) -> Scale {
        return Scale(x: lhs.x * rhs.x, y: lhs.y * rhs.y)
    }

    /// Scale by factor
    static func * (lhs: Scale, rhs: Float) -> Scale {
        return Scale(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

public extension Rotation {
    /// Add rotations
    static func + (lhs: Rotation, rhs: Rotation) -> Rotation {
        return Rotation(degrees: lhs.degrees + rhs.degrees)
    }

    /// Subtract rotations
    static func - (lhs: Rotation, rhs: Rotation) -> Rotation {
        return Rotation(degrees: lhs.degrees - rhs.degrees)
    }

    /// Negate rotation
    static prefix func - (rotation: Rotation) -> Rotation {
        return Rotation(degrees: -rotation.degrees)
    }
}
