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
	public let right: Int32  // not inclusive
	public let top: Int32
	public let bottom: Int32 // not inclusive
	
	public init(x: Int32, y: Int32, width: Int32, height: Int32) {
		// Assume that width and height are positive
		self.left = x
		self.right = x + width
		self.top = y
		self.bottom = y + height
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
	public var cValue: UInt32 { rawValue }
}

/// Bitmap Reflection modes - Swift wrapper for LCDBitmapFlip
public enum BitmapFlip: UInt32 {
	case none = 0
	case x = 1
	case y = 2
	case xy = 3
	
	/// Conversion to C enum value
	public var cValue: UInt32 { rawValue }
}

// MARK: - Colors and Patterns
/// Solid Colors - Swift wrapper for LCDSolidColor
public enum SolidColor: UInt32, Sendable {
	case black = 0
	case white = 1
	case clear = 2
	case xor = 3
	
	/// Conversion to C enum value
	public var cValue: UInt32 { rawValue }
}

/// An 8x8 pixel fill pattern
/// Swift wrapper for LCDPattern (16 bytes: 8 bytes of image + 8 bytes of mask)
public struct Pattern: Sendable {
	public let bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
					   UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
	
	/// Creating a pattern with 8 image lines (the mask will be 0xFF for opacity)
	public init(rows r0: UInt8, _ r1: UInt8, _ r2: UInt8, _ r3: UInt8, 
				_ r4: UInt8, _ r5: UInt8, _ r6: UInt8, _ r7: UInt8) {
		self.bytes = (r0, r1, r2, r3, r4, r5, r6, r7,
					  0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF)
	}
	
	/// Creating a pattern with an image and a mask
	public init(imageRows: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
				maskRows: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
		self.bytes = (imageRows.0, imageRows.1, imageRows.2, imageRows.3,
					  imageRows.4, imageRows.5, imageRows.6, imageRows.7,
					  maskRows.0, maskRows.1, maskRows.2, maskRows.3,
					  maskRows.4, maskRows.5, maskRows.6, maskRows.7)
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
}

// MARK: - Line and Font Settings
/// Line Endings style - Swift wrapper for LCDLineCapStyle
public enum LineCapStyle: UInt32 {
	case butt = 0
	case square = 1  
	case round = 2
	
	/// Conversion to C enum value
	public var cValue: UInt32 { rawValue }
}

/// Font Languages - Swift wrapper for LCDFontLanguage
public enum FontLanguage: UInt32 {
	case english = 0
	case japanese = 1
	case unknown = 2
	
	/// Conversion to C enum value
	public var cValue: UInt32 { rawValue }
}

/// String Encodings - Swift wrapper for PDStringEncoding
public enum StringEncoding: UInt32 {
	case ascii = 0
	case utf8 = 1
	case utf16LE = 2
	
	/// Conversion to C enum value
	public var cValue: UInt32 { rawValue }
}

// MARK: - Polygon and Text Settings
/// Polygon filling rules - Swift wrapper for LCDPolygonFillRule
public enum PolygonFillRule: UInt32 {
	case nonZero = 0
	case evenOdd = 1
	
	/// Conversion to C enum value
	public var cValue: UInt32 { rawValue }
}

/// Text wrapping Modes - Swift wrapper for PDTextWrappingMode
public enum TextWrappingMode: UInt32 {
	case clip = 0
	case character = 1
	case word = 2
	
	/// Conversion to C enum value
	public var cValue: UInt32 { rawValue }
}

/// Text Alignment - Swift wrapper for PDTextAlignment
public enum TextAlignment: UInt32 {
	case left = 0
	case center = 1
	case right = 2
	
	/// Conversion to C enum value
	public var cValue: UInt32 { rawValue }
}

// MARK: - Extensions для удобства работы
extension Point {
	/// Zero Point
	public static let zero = Point(x: 0, y: 0)
}

extension Size {
	/// Zero Size
	public static let zero = Size(width: 0, height: 0)
}

extension Rect {
	/// Zero Rect
	public static let zero = Rect(x: 0, y: 0, width: 0, height: 0)
	
	/// Checking if the rectangle is empty
	public var isEmpty: Bool {
		return width <= 0 || height <= 0
	}
}