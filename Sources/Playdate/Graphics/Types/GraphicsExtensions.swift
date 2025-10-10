//
//  Extensions.swift
//  Playdate Graphics SDK
//
//  Convenience extensions for geometric types and colors
//

// MARK: - Point Extensions

public extension Point {
    // MARK: Arithmetic Operators

    /// Add two points together
    static func + (lhs: Point, rhs: Point) -> Point {
        return Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    /// Subtract one point from another
    static func - (lhs: Point, rhs: Point) -> Point {
        return Point(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    /// Multiply point by scalar
    static func * (lhs: Point, rhs: Int32) -> Point {
        return Point(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    /// Multiply point by scalar (reverse order)
    static func * (lhs: Int32, rhs: Point) -> Point {
        return Point(x: rhs.x * lhs, y: rhs.y * lhs)
    }

    /// Divide point by scalar
    static func / (lhs: Point, rhs: Int32) -> Point {
        guard rhs != 0 else {
            // Return original point if division by zero
            return lhs
        }
        return Point(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    // MARK: Compound Assignment Operators

    /// Add and assign
    static func += (lhs: inout Point, rhs: Point) {
        lhs = lhs + rhs
    }

    /// Subtract and assign
    static func -= (lhs: inout Point, rhs: Point) {
        lhs = lhs - rhs
    }

    /// Multiply and assign
    static func *= (lhs: inout Point, rhs: Int32) {
        lhs = lhs * rhs
    }

    /// Divide and assign
    static func /= (lhs: inout Point, rhs: Int32) {
        lhs = lhs / rhs
    }

    // MARK: Distance Calculations

    /// Calculate squared distance to another point (faster than distance)
    /// Use this when you only need to compare distances
    func distanceSquared(to other: Point) -> Int32 {
        let dx = other.x - x
        let dy = other.y - y
        return dx * dx + dy * dy
    }

    /// Calculate actual distance to another point
    /// Note: Uses integer square root approximation for performance
    func distance(to other: Point) -> Int32 {
        let distSq = distanceSquared(to: other)
        return integerSquareRoot(distSq)
    }

    // MARK: Geometric Operations

    /// Create a new point offset by dx and dy
    func offset(by dx: Int32, _ dy: Int32) -> Point {
        return Point(x: x + dx, y: y + dy)
    }

    /// Create a new point offset by another point
    func offset(by other: Point) -> Point {
        return Point(x: x + other.x, y: y + other.y)
    }

    /// Clamp point to bounds of a rectangle
    func clamped(to rect: Rect) -> Point {
        let clampedX = max(rect.left, min(x, rect.right - 1))
        let clampedY = max(rect.top, min(y, rect.bottom - 1))
        return Point(x: clampedX, y: clampedY)
    }

    /// Check if point is inside a rectangle
    func isInside(_ rect: Rect) -> Bool {
        return x >= rect.left && x < rect.right &&
            y >= rect.top && y < rect.bottom
    }

    /// Negate both coordinates
    func negated() -> Point {
        return Point(x: -x, y: -y)
    }

    // MARK: Static Constants

    /// Center of the Playdate screen
    static let screenCenter = Point(
        x: Screen.columns / 2,
        y: Screen.rows / 2
    )

    /// Top-left corner of screen
    static let screenTopLeft = Point(x: 0, y: 0)

    /// Top-right corner of screen
    static let screenTopRight = Point(x: Screen.columns, y: 0)

    /// Bottom-left corner of screen
    static let screenBottomLeft = Point(x: 0, y: Screen.rows)

    /// Bottom-right corner of screen
    static let screenBottomRight = Point(x: Screen.columns, y: Screen.rows)
}

// MARK: - Point Equatable & Hashable

extension Point: Equatable, Hashable {
    public static func == (lhs: Point, rhs: Point) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

// MARK: - Point CustomStringConvertible

extension Point: CustomStringConvertible {
    public var description: String {
        return "Point(x: \(x), y: \(y))"
    }
}

// MARK: - Size Extensions

public extension Size {
    // MARK: Arithmetic Operators

    /// Add two sizes together
    static func + (lhs: Size, rhs: Size) -> Size {
        return Size(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }

    /// Subtract one size from another
    static func - (lhs: Size, rhs: Size) -> Size {
        return Size(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }

    /// Multiply size by scalar
    static func * (lhs: Size, rhs: Int32) -> Size {
        return Size(width: lhs.width * rhs, height: lhs.height * rhs)
    }

    /// Multiply size by scalar (reverse order)
    static func * (lhs: Int32, rhs: Size) -> Size {
        return Size(width: rhs.width * lhs, height: rhs.height * lhs)
    }

    /// Divide size by scalar
    static func / (lhs: Size, rhs: Int32) -> Size {
        guard rhs != 0 else {
            return lhs
        }
        return Size(width: lhs.width / rhs, height: lhs.height / rhs)
    }

    // MARK: Compound Assignment Operators

    /// Add and assign
    static func += (lhs: inout Size, rhs: Size) {
        lhs = lhs + rhs
    }

    /// Subtract and assign
    static func -= (lhs: inout Size, rhs: Size) {
        lhs = lhs - rhs
    }

    /// Multiply and assign
    static func *= (lhs: inout Size, rhs: Int32) {
        lhs = lhs * rhs
    }

    /// Divide and assign
    static func /= (lhs: inout Size, rhs: Int32) {
        lhs = lhs / rhs
    }

    // MARK: Computed Properties

    /// Calculate area (width * height)
    var area: Int32 {
        return width * height
    }

    /// Aspect ratio (width / height)
    /// Returns 0 if height is 0
    var aspectRatio: Float {
        guard height != 0 else { return 0 }
        return Float(width) / Float(height)
    }

    /// Check if size is empty (width or height <= 0)
    var isEmpty: Bool {
        return width <= 0 || height <= 0
    }

    /// Check if size is square
    var isSquare: Bool {
        return width == height
    }

    // MARK: Geometric Operations

    /// Scale size by factor, maintaining aspect ratio
    func scaled(by factor: Int32) -> Size {
        return Size(width: width * factor, height: height * factor)
    }

    /// Scale size by different factors for width and height
    func scaled(byWidth widthFactor: Int32, height heightFactor: Int32) -> Size {
        return Size(width: width * widthFactor, height: height * heightFactor)
    }

    /// Check if this size fits inside another size
    func fitsInside(_ other: Size) -> Bool {
        return width <= other.width && height <= other.height
    }

    /// Expand size by adding padding on all sides
    func expanded(by padding: Int32) -> Size {
        return Size(width: width + padding * 2, height: height + padding * 2)
    }

    /// Shrink size by removing padding from all sides
    func inset(by padding: Int32) -> Size {
        let newWidth = max(0, width - padding * 2)
        let newHeight = max(0, height - padding * 2)
        return Size(width: newWidth, height: newHeight)
    }

    // MARK: Static Constants

    /// Size of the Playdate screen
    static let screen = Size(width: Screen.columns, height: Screen.rows)
}

// MARK: - Size Equatable & Comparable

extension Size: Equatable, Comparable, Hashable {
    public static func == (lhs: Size, rhs: Size) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }

    /// Compare sizes by area
    public static func < (lhs: Size, rhs: Size) -> Bool {
        return lhs.area < rhs.area
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}

// MARK: - Size CustomStringConvertible

extension Size: CustomStringConvertible {
    public var description: String {
        return "Size(width: \(width), height: \(height))"
    }
}

// MARK: - Helper Functions

/// Integer square root approximation using Newton's method
/// Optimized for Playdate's integer arithmetic
private func integerSquareRoot(_ n: Int32) -> Int32 {
    guard n > 0 else { return 0 }

    var x = n
    var y = (x + 1) / 2

    while y < x {
        x = y
        y = (x + n / x) / 2
    }

    return x
}

// MARK: - Rect Extensions

public extension Rect {
    // MARK: Additional Initializers

    /// Create rect from origin point and size
    init(origin: Point, size: Size) {
        self.init(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }

    /// Create rect centered at a point with given size
    init(center: Point, size: Size) {
        let x = center.x - size.width / 2
        let y = center.y - size.height / 2
        self.init(x: x, y: y, width: size.width, height: size.height)
    }

    /// Create rect from two corner points
    init(from point1: Point, to point2: Point) {
        let minX = min(point1.x, point2.x)
        let maxX = max(point1.x, point2.x)
        let minY = min(point1.y, point2.y)
        let maxY = max(point1.y, point2.y)
        self.init(left: minX, top: minY, right: maxX, bottom: maxY)
    }

    // MARK: Computed Properties - Coordinates

    /// Minimum X coordinate (left edge)
    var minX: Int32 { left }

    /// Middle X coordinate
    var midX: Int32 { (left + right) / 2 }

    /// Maximum X coordinate (right edge - 1, since right is not inclusive)
    var maxX: Int32 { right - 1 }

    /// Minimum Y coordinate (top edge)
    var minY: Int32 { top }

    /// Middle Y coordinate
    var midY: Int32 { (top + bottom) / 2 }

    /// Maximum Y coordinate (bottom edge - 1, since bottom is not inclusive)
    var maxY: Int32 { bottom - 1 }

    // MARK: Computed Properties - Geometric

    /// Center point of the rectangle
    var center: Point {
        return Point(x: midX, y: midY)
    }

    /// Origin point (top-left corner)
    var origin: Point {
        return Point(x: left, y: top)
    }

    /// Size of the rectangle
    var size: Size {
        return Size(width: width, height: height)
    }

    /// All four corners as an array: [topLeft, topRight, bottomRight, bottomLeft]
    var corners: [Point] {
        return [
            Point(x: left, y: top), // top-left
            Point(x: right - 1, y: top), // top-right
            Point(x: right - 1, y: bottom - 1), // bottom-right
            Point(x: left, y: bottom - 1), // bottom-left
        ]
    }

    // MARK: Geometric Operations - Intersection & Union

    /// Calculate intersection with another rectangle
    /// Returns nil if rectangles don't intersect
    func intersection(_ other: Rect) -> Rect? {
        let newLeft = max(left, other.left)
        let newTop = max(top, other.top)
        let newRight = min(right, other.right)
        let newBottom = min(bottom, other.bottom)

        // Check if intersection is valid
        guard newLeft < newRight, newTop < newBottom else {
            return nil
        }

        return Rect(left: newLeft, top: newTop, right: newRight, bottom: newBottom)
    }

    /// Calculate union (smallest rectangle containing both rectangles)
    func union(_ other: Rect) -> Rect {
        let newLeft = min(left, other.left)
        let newTop = min(top, other.top)
        let newRight = max(right, other.right)
        let newBottom = max(bottom, other.bottom)

        return Rect(left: newLeft, top: newTop, right: newRight, bottom: newBottom)
    }

    /// Check if this rectangle intersects with another
    func intersects(_ other: Rect) -> Bool {
        return left < other.right &&
            right > other.left &&
            top < other.bottom &&
            bottom > other.top
    }

    // MARK: Geometric Operations - Contains

    /// Check if rectangle contains a point
    func contains(_ point: Point) -> Bool {
        return point.x >= left && point.x < right &&
            point.y >= top && point.y < bottom
    }

    /// Check if rectangle completely contains another rectangle
    func contains(_ other: Rect) -> Bool {
        return other.left >= left &&
            other.right <= right &&
            other.top >= top &&
            other.bottom <= bottom
    }

    // MARK: Geometric Operations - Transformations

    /// Offset rectangle by delta values
    func offset(by dx: Int32, _ dy: Int32) -> Rect {
        return Rect(
            left: left + dx,
            top: top + dy,
            right: right + dx,
            bottom: bottom + dy
        )
    }

    /// Offset rectangle by a point
    func offset(by point: Point) -> Rect {
        return offset(by: point.x, point.y)
    }

    /// Inset rectangle by specified amount on all sides
    /// Positive values shrink, negative values expand
    func inset(by amount: Int32) -> Rect {
        return Rect(
            left: left + amount,
            top: top + amount,
            right: right - amount,
            bottom: bottom - amount
        )
    }

    /// Inset rectangle by different amounts on each axis
    func inset(byX dx: Int32, y dy: Int32) -> Rect {
        return Rect(
            left: left + dx,
            top: top + dy,
            right: right - dx,
            bottom: bottom - dy
        )
    }

    /// Inset rectangle by individual edge amounts
    func inset(
        left l: Int32,
        top t: Int32,
        right r: Int32,
        bottom b: Int32
    ) -> Rect {
        return Rect(
            left: left + l,
            top: top + t,
            right: right - r,
            bottom: bottom - b
        )
    }

    /// Scale rectangle from its center
    func scaled(by factor: Int32) -> Rect {
        let newWidth = width * factor
        let newHeight = height * factor
        let newX = midX - newWidth / 2
        let newY = midY - newHeight / 2
        return Rect(x: newX, y: newY, width: newWidth, height: newHeight)
    }

    /// Ensure rectangle is within bounds of another rectangle
    func clamped(to bounds: Rect) -> Rect {
        var newLeft = left
        var newTop = top
        var newRight = right
        var newBottom = bottom

        // Clamp position
        if newLeft < bounds.left {
            let offset = bounds.left - newLeft
            newLeft += offset
            newRight += offset
        }
        if newTop < bounds.top {
            let offset = bounds.top - newTop
            newTop += offset
            newBottom += offset
        }

        // Clamp size if too large
        if newRight > bounds.right {
            newRight = bounds.right
        }
        if newBottom > bounds.bottom {
            newBottom = bounds.bottom
        }

        return Rect(left: newLeft, top: newTop, right: newRight, bottom: newBottom)
    }

    // MARK: Static Factory Methods

    /// Create bounding rectangle for an array of points
    /// Returns nil if array is empty
    static func boundingRect(for points: [Point]) -> Rect? {
        guard !points.isEmpty else { return nil }

        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return Rect(left: minX, top: minY, right: maxX + 1, bottom: maxY + 1)
    }

    /// Create bounding rectangle for an array of rectangles
    /// Returns nil if array is empty
    static func boundingRect(for rects: [Rect]) -> Rect? {
        guard !rects.isEmpty else { return nil }

        var result = rects[0]
        for rect in rects.dropFirst() {
            result = result.union(rect)
        }

        return result
    }

    // MARK: Validation

    /// Check if rectangle has valid dimensions (non-negative width and height)
    var isValid: Bool {
        return right >= left && bottom >= top
    }

    /// Normalize rectangle to ensure valid bounds
    /// Swaps coordinates if needed so that left < right and top < bottom
    func normalized() -> Rect {
        let newLeft = min(left, right)
        let newRight = max(left, right)
        let newTop = min(top, bottom)
        let newBottom = max(top, bottom)
        return Rect(left: newLeft, top: newTop, right: newRight, bottom: newBottom)
    }
}

// MARK: - Rect Equatable & Hashable

extension Rect: Equatable, Hashable {
    public static func == (lhs: Rect, rhs: Rect) -> Bool {
        return lhs.left == rhs.left &&
            lhs.right == rhs.right &&
            lhs.top == rhs.top &&
            lhs.bottom == rhs.bottom
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(left)
        hasher.combine(right)
        hasher.combine(top)
        hasher.combine(bottom)
    }
}

// MARK: - Rect CustomStringConvertible

extension Rect: CustomStringConvertible {
    public var description: String {
        return "Rect(x: \(x), y: \(y), width: \(width), height: \(height))"
    }
}

// MARK: - Color Extensions

public extension Color {
    // MARK: Color Properties

    /// Check if color is opaque (not clear or transparent)
    var isOpaque: Bool {
        switch self {
        case let .solid(solidColor):
            return solidColor != .clear
        case .pattern:
            return true // Patterns are considered opaque
        }
    }

    /// Check if color is a solid color
    var isSolid: Bool {
        if case .solid = self {
            return true
        }
        return false
    }

    /// Check if color is a pattern
    var isPattern: Bool {
        if case .pattern = self {
            return true
        }
        return false
    }

    /// Get inverted color
    var inverted: Color {
        switch self {
        case let .solid(solidColor):
            switch solidColor {
            case .black: return .white
            case .white: return .black
            case .clear: return .clear
            case .xor: return .xor
            }
        case let .pattern(pattern):
            return .pattern(pattern.inverted)
        }
    }

    // MARK: C API Conversion

    /// Convert Color to LCDColor (uintptr_t) for C API
    /// This creates a pointer to the pattern data or returns solid color value
    internal func toLCDColor() -> UInt {
        switch self {
        case let .solid(solidColor):
            return UInt(solidColor.rawValue)
        case let .pattern(pattern):
            // For patterns, we need to pass a pointer
            // This will be handled by the renderer when drawing
            return withUnsafePointer(to: pattern.bytes) { ptr in
                UInt(bitPattern: ptr)
            }
        }
    }

    // MARK: Predefined Pattern Colors

    /// 50% dithered pattern (checkerboard)
    static let dithered = Color.pattern(.checkerboard)

    /// Horizontal stripes pattern
    static let horizontalStripes = Color.pattern(.horizontal)

    /// Vertical stripes pattern
    static let verticalStripes = Color.pattern(.vertical)

    /// Diagonal stripes pattern
    static let diagonalStripes = Color.pattern(.diagonal)

    /// Dots pattern
    static let dots = Color.pattern(.dots)

    /// Grid pattern
    static let grid = Color.pattern(.grid)
}

// MARK: - Color Equatable

extension Color: Equatable {
    public static func == (lhs: Color, rhs: Color) -> Bool {
        switch (lhs, rhs) {
        case let (.solid(lColor), .solid(rColor)):
            return lColor == rColor
        case let (.pattern(lPattern), .pattern(rPattern)):
            return lPattern == rPattern
        default:
            return false
        }
    }
}

// MARK: - Color CustomStringConvertible

extension Color: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .solid(solidColor):
            return "Color.solid(.\(solidColor))"
        case .pattern:
            return "Color.pattern(...)"
        }
    }
}

// MARK: - Pattern Extensions

public extension Pattern {
    // MARK: Predefined Patterns

    /// Checkerboard pattern (50% dithering)
    /// ▓░▓░▓░▓░
    /// ░▓░▓░▓░▓
    static let checkerboard = Pattern(
        rows: 0b1010_1010,
        0b0101_0101,
        0b1010_1010,
        0b0101_0101,
        0b1010_1010,
        0b0101_0101,
        0b1010_1010,
        0b0101_0101
    )

    /// Horizontal stripes (alternating rows)
    /// ████████
    /// ░░░░░░░░
    static let horizontal = Pattern(
        rows: 0b1111_1111,
        0b0000_0000,
        0b1111_1111,
        0b0000_0000,
        0b1111_1111,
        0b0000_0000,
        0b1111_1111,
        0b0000_0000
    )

    /// Vertical stripes (alternating columns)
    /// █░█░█░█░
    /// █░█░█░█░
    static let vertical = Pattern(
        rows: 0b1010_1010,
        0b1010_1010,
        0b1010_1010,
        0b1010_1010,
        0b1010_1010,
        0b1010_1010,
        0b1010_1010,
        0b1010_1010
    )

    /// Diagonal stripes (top-left to bottom-right)
    /// █░░░░░░░
    /// ░█░░░░░░
    static let diagonal = Pattern(
        rows: 0b1000_0000,
        0b0100_0000,
        0b0010_0000,
        0b0001_0000,
        0b0000_1000,
        0b0000_0100,
        0b0000_0010,
        0b0000_0001
    )

    /// Dots pattern (scattered pixels)
    /// █░░░█░░░
    /// ░░░░░░░░
    static let dots = Pattern(
        rows: 0b1000_1000,
        0b0000_0000,
        0b0010_0010,
        0b0000_0000,
        0b1000_1000,
        0b0000_0000,
        0b0010_0010,
        0b0000_0000
    )

    /// Grid pattern (outlines only)
    /// ████████
    /// █░░░░░░█
    static let grid = Pattern(
        rows: 0b1111_1111,
        0b1000_0001,
        0b1000_0001,
        0b1000_0001,
        0b1000_0001,
        0b1000_0001,
        0b1000_0001,
        0b1111_1111
    )

    /// 75% filled pattern
    /// ███░███░
    /// ██████░█
    static let dithered75 = Pattern(
        rows: 0b1110_1110,
        0b1111_1101,
        0b1110_1110,
        0b0111_1111,
        0b1110_1110,
        0b1111_1101,
        0b1110_1110,
        0b0111_1111
    )

    /// 25% filled pattern
    /// █░░░░░░░
    /// ░░░█░░░░
    static let dithered25 = Pattern(
        rows: 0b1000_0000,
        0b0000_1000,
        0b0000_0010,
        0b0010_0000,
        0b1000_0000,
        0b0000_1000,
        0b0000_0010,
        0b0010_0000
    )

    /// Solid black pattern
    /// ████████
    /// ████████
    static let solid = Pattern(
        rows: 0b1111_1111,
        0b1111_1111,
        0b1111_1111,
        0b1111_1111,
        0b1111_1111,
        0b1111_1111,
        0b1111_1111,
        0b1111_1111
    )

    /// Empty (transparent) pattern
    /// ░░░░░░░░
    /// ░░░░░░░░
    static let empty = Pattern(
        rows: 0b0000_0000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000
    )

    // MARK: Pattern Transformations

    /// Get inverted pattern (swap 0s and 1s)
    var inverted: Pattern {
        return Pattern(
            imageRows: (
                ~bytes.0, ~bytes.1, ~bytes.2, ~bytes.3,
                ~bytes.4, ~bytes.5, ~bytes.6, ~bytes.7
            ),
            maskRows: (
                bytes.8, bytes.9, bytes.10, bytes.11,
                bytes.12, bytes.13, bytes.14, bytes.15
            )
        )
    }

    /// Rotate pattern 90 degrees clockwise
    var rotated90: Pattern {
        var newImage: [UInt8] = Array(repeating: 0, count: 8)
        var newMask: [UInt8] = Array(repeating: 0, count: 8)

        // Transpose and reverse columns for 90° rotation
        for row in 0 ..< 8 {
            let imageRow = getImageRow(row)
            let maskRow = getMaskRow(row)

            for col in 0 ..< 8 {
                let bit = (imageRow >> (7 - col)) & 1
                let maskBit = (maskRow >> (7 - col)) & 1

                let newCol = 7 - row
                let newRow = col

                newImage[newRow] |= bit << (7 - newCol)
                newMask[newRow] |= maskBit << (7 - newCol)
            }
        }

        return Pattern(
            imageRows: (newImage[0], newImage[1], newImage[2], newImage[3],
                        newImage[4], newImage[5], newImage[6], newImage[7]),
            maskRows: (newMask[0], newMask[1], newMask[2], newMask[3],
                       newMask[4], newMask[5], newMask[6], newMask[7])
        )
    }

    /// Mirror pattern horizontally
    var mirroredHorizontally: Pattern {
        return Pattern(
            imageRows: (
                reverseBits(bytes.0), reverseBits(bytes.1),
                reverseBits(bytes.2), reverseBits(bytes.3),
                reverseBits(bytes.4), reverseBits(bytes.5),
                reverseBits(bytes.6), reverseBits(bytes.7)
            ),
            maskRows: (
                reverseBits(bytes.8), reverseBits(bytes.9),
                reverseBits(bytes.10), reverseBits(bytes.11),
                reverseBits(bytes.12), reverseBits(bytes.13),
                reverseBits(bytes.14), reverseBits(bytes.15)
            )
        )
    }

    /// Mirror pattern vertically
    var mirroredVertically: Pattern {
        return Pattern(
            imageRows: (
                bytes.7, bytes.6, bytes.5, bytes.4,
                bytes.3, bytes.2, bytes.1, bytes.0
            ),
            maskRows: (
                bytes.15, bytes.14, bytes.13, bytes.12,
                bytes.11, bytes.10, bytes.9, bytes.8
            )
        )
    }

    // MARK: Helper Methods

    /// Get image row at index (0-7)
    private func getImageRow(_ index: Int) -> UInt8 {
        switch index {
        case 0: return bytes.0
        case 1: return bytes.1
        case 2: return bytes.2
        case 3: return bytes.3
        case 4: return bytes.4
        case 5: return bytes.5
        case 6: return bytes.6
        case 7: return bytes.7
        default: return 0
        }
    }

    /// Get mask row at index (0-7)
    private func getMaskRow(_ index: Int) -> UInt8 {
        switch index {
        case 0: return bytes.8
        case 1: return bytes.9
        case 2: return bytes.10
        case 3: return bytes.11
        case 4: return bytes.12
        case 5: return bytes.13
        case 6: return bytes.14
        case 7: return bytes.15
        default: return 0xFF
        }
    }

    /// Reverse bits in a byte
    private func reverseBits(_ byte: UInt8) -> UInt8 {
        var result: UInt8 = 0
        var value = byte
        for _ in 0 ..< 8 {
            result = (result << 1) | (value & 1)
            value >>= 1
        }
        return result
    }
}

// MARK: - Pattern Equatable

extension Pattern: Equatable {
    public static func == (lhs: Pattern, rhs: Pattern) -> Bool {
        return lhs.bytes.0 == rhs.bytes.0 &&
            lhs.bytes.1 == rhs.bytes.1 &&
            lhs.bytes.2 == rhs.bytes.2 &&
            lhs.bytes.3 == rhs.bytes.3 &&
            lhs.bytes.4 == rhs.bytes.4 &&
            lhs.bytes.5 == rhs.bytes.5 &&
            lhs.bytes.6 == rhs.bytes.6 &&
            lhs.bytes.7 == rhs.bytes.7 &&
            lhs.bytes.8 == rhs.bytes.8 &&
            lhs.bytes.9 == rhs.bytes.9 &&
            lhs.bytes.10 == rhs.bytes.10 &&
            lhs.bytes.11 == rhs.bytes.11 &&
            lhs.bytes.12 == rhs.bytes.12 &&
            lhs.bytes.13 == rhs.bytes.13 &&
            lhs.bytes.14 == rhs.bytes.14 &&
            lhs.bytes.15 == rhs.bytes.15
    }
}

// MARK: - Pattern CustomStringConvertible

extension Pattern: CustomStringConvertible {
    public var description: String {
        var result = "Pattern(\n"
        for row in 0 ..< 8 {
            let imageRow = getImageRow(row)
            result += "  "
            for bit in 0 ..< 8 {
                let isSet = (imageRow >> (7 - bit)) & 1 == 1
                result += isSet ? "█" : "░"
            }
            result += "\n"
        }
        result += ")"
        return result
    }
}

public extension Pattern {
    /// Execute body with this pattern as LCDColor value
    /// Ensures pattern data remains valid during execution
    ///
    /// Example:
    /// ```swift
    /// let pattern = Pattern(rows: 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55)
    /// pattern.withColorValue { color in
    ///     graphicsAPI.setColor(color)
    ///     graphicsAPI.fillRect(x, y, width, height, color)
    /// }
    /// ```
    func withColorValue<Result>(_ body: (LCDColor) -> Result) -> Result {
        return withUnsafeBytes(of: bytes) { buffer in
            let color = LCDColor(UInt(bitPattern: buffer.baseAddress))
            return body(color)
        }
    }
}

// MARK: - Convenience Type Aliases

/// Convenience typealias for common rect operations
public typealias Rectangle = Rect

/// Convenience typealias for points
public typealias Coordinate = Point

/// Convenience typealias for dimensions
public typealias Dimensions = Size
