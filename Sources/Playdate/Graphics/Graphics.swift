import CPlaydate

private var graphicsAPI: playdate_graphics { playdateAPI.graphics.unsafelyUnwrapped.pointee }

public enum Graphics {}

// ============================================================================

// MARK: - Font & Text Rendering

// ============================================================================
//
// Add this section to Graphics.swift
//
// This section provides text drawing and font management functionality.
// All methods are static and operate on the current graphics context.

public extension Graphics {
    // MARK: - Text Drawing

    /// Draw text at specified position
    ///
    /// Draws text using the current font. If no font has been set,
    /// the default system font (Asheville Sans 14 Light) is used.
    ///
    /// - Parameters:
    ///   - text: Text string to draw
    ///   - position: Position to draw text (top-left corner)
    ///   - encoding: String encoding (default: UTF-8)
    /// - Returns: Width of drawn text in pixels
    ///
    /// From Playdate SDK:
    /// > "Draws the given text using the provided options. If no font has been
    /// > set with setFont, the default system font Asheville Sans 14 Light is used."
    ///
    /// Example:
    /// ```swift
    /// // Draw with current font
    /// Graphics.drawText("Hello World", at: Point(x: 100, y: 50))
    ///
    /// // Set custom font first
    /// let font = Font.load(path: "fonts/Title").get()
    /// font.setAsCurrent()
    /// Graphics.drawText("Title Text", at: Point(x: 10, y: 10))
    ///
    /// // Different encoding
    /// Graphics.drawText("ASCII", at: Point(x: 10, y: 30), encoding: .ascii)
    /// ```
    @discardableResult
    static func drawText(
        _ text: String,
        at position: Point,
        encoding: StringEncoding = .utf8
    ) -> Int32 {
        return text.withCString { cString in
            let length = text.utf8.count

            return graphicsAPI.drawText(
                cString,
                length,
                encoding.cValue,
                position.x,
                position.y
            )
        }
    }

    /// Draw text in rectangle with wrapping and alignment
    ///
    /// Draws text within a rectangular area with automatic wrapping
    /// and alignment options.
    ///
    /// - Parameters:
    ///   - text: Text string to draw
    ///   - rect: Rectangle to draw text within
    ///   - wrap: Text wrapping mode (default: word)
    ///   - align: Text alignment (default: left)
    ///   - encoding: String encoding (default: UTF-8)
    ///
    /// From Playdate SDK:
    /// > "Draws the text in the given rectangle using the provided options.
    /// > If no font has been set with setFont, the default system font
    /// > Asheville Sans 14 Light is used."
    ///
    /// Example:
    /// ```swift
    /// let textRect = Rect(x: 10, y: 10, width: 200, height: 100)
    ///
    /// // Draw with word wrapping, left aligned
    /// Graphics.drawText(
    ///     "This is a long text that will wrap automatically",
    ///     in: textRect,
    ///     wrap: .word,
    ///     align: .left
    /// )
    ///
    /// // Center aligned with character wrapping
    /// Graphics.drawText(
    ///     "Centered text",
    ///     in: textRect,
    ///     wrap: .character,
    ///     align: .center
    /// )
    ///
    /// // Clipped text (no wrapping)
    /// Graphics.drawText(
    ///     "Clipped",
    ///     in: textRect,
    ///     wrap: .clip,
    ///     align: .right
    /// )
    /// ```
    static func drawText(
        _ text: String,
        in rect: Rect,
        wrap: TextWrappingMode = .word,
        align: TextAlignment = .left,
        encoding: StringEncoding = .utf8
    ) {
        text.withCString { cString in
            let length = text.utf8.count

            graphicsAPI.drawTextInRect(
                cString,
                length,
                encoding.cValue,
                rect.x,
                rect.y,
                rect.width,
                rect.height,
                wrap.cValue,
                align.cValue
            )
        }
    }

    /// Draw text centered at position
    ///
    /// Convenience method that draws text centered at the specified point.
    ///
    /// - Parameters:
    ///   - text: Text to draw
    ///   - center: Center point for text
    ///   - font: Font to use (optional, uses current if nil)
    ///   - encoding: String encoding (default: UTF-8)
    /// - Returns: Width of drawn text
    ///
    /// Example:
    /// ```swift
    /// // Draw text centered on screen
    /// Graphics.drawTextCentered(
    ///     "Centered",
    ///     at: Point(x: 200, y: 120)
    /// )
    /// ```
    @discardableResult
    static func drawTextCentered(
        _ text: String,
        at center: Point,
        font: Font? = nil,
        encoding: StringEncoding = .utf8
    ) -> Int32 {
        // Get text width (use provided font or measure with current)
        let width: Int32
        if let font = font {
            width = font.getTextWidth(text, encoding: encoding)
        } else {
            // Would need to get current font to measure
            // For now, draw and measure
            let tempWidth = text.withCString { _ in
                // This is a limitation - C API doesn't provide "get current font"
                // So we'll just estimate or require font parameter
                Int32(text.utf8.count * 8) // rough estimate
            }
            width = tempWidth
        }

        let position = Point(
            x: center.x - width / 2,
            y: center.y
        )

        return drawText(text, at: position, encoding: encoding)
    }

    // MARK: - Font Management

    /// Set font for subsequent text drawing operations
    ///
    /// Sets the font to use for all text drawing. Pass nil to use the
    /// default system font.
    ///
    /// - Parameter font: Font to use (nil for system font)
    ///
    /// Example:
    /// ```swift
    /// // Set custom font
    /// let titleFont = Font.load(path: "fonts/Title").get()
    /// Graphics.setFont(titleFont)
    /// Graphics.drawText("Title", at: Point(x: 10, y: 10))
    ///
    /// // Reset to system font
    /// Graphics.setFont(nil)
    /// Graphics.drawText("Body text", at: Point(x: 10, y: 30))
    /// ```
    static func setFont(_ font: Font?) {
        if let font = font {
            graphicsAPI.setFont(font.cPointer)
        } else {
            // nil means use default system font
            setDefaultFont()
        }
    }

    /// Set default system font
    ///
    /// Resets text rendering to use the default Playdate system font
    /// (Asheville Sans 14 Light).
    ///
    /// Example:
    /// ```swift
    /// // Use custom font
    /// Graphics.setFont(customFont)
    /// Graphics.drawText("Custom", at: Point(x: 10, y: 10))
    ///
    /// // Reset to default
    /// Graphics.setDefaultFont()
    /// Graphics.drawText("Default", at: Point(x: 10, y: 30))
    /// ```
    static func setDefaultFont() {
        // Setting font to NULL uses system font
        graphicsAPI.setFont(nil)
    }

    /// Execute drawing with temporary font
    ///
    /// Sets font for the duration of the closure, useful for one-off text.
    /// Note: Does not restore previous font after closure.
    ///
    /// - Parameters:
    ///   - font: Font to use temporarily
    ///   - draw: Closure to execute with font
    /// - Throws: Rethrows any error from the closure
    ///
    /// Example:
    /// ```swift
    /// try Graphics.withFont(specialFont) {
    ///     Graphics.drawText("Special", at: Point(x: 10, y: 10))
    ///     Graphics.drawText("More", at: Point(x: 10, y: 30))
    /// }
    /// ```
    static func withFont<T>(_ font: Font?, _ draw: () throws -> T) rethrows -> T {
        setFont(font)
        return try draw()
    }

    // MARK: - Text Settings

    /// Set character spacing (tracking) for text rendering
    ///
    /// Sets the tracking (additional space between characters) for
    /// subsequent text drawing operations.
    ///
    /// - Parameter tracking: Additional spacing in pixels (can be negative)
    ///
    /// From Playdate SDK:
    /// > "Sets the tracking to use when drawing text."
    ///
    /// Example:
    /// ```swift
    /// // Tight spacing
    /// Graphics.setTextTracking(-1)
    /// Graphics.drawText("Tight", at: Point(x: 10, y: 10))
    ///
    /// // Normal spacing
    /// Graphics.setTextTracking(0)
    /// Graphics.drawText("Normal", at: Point(x: 10, y: 30))
    ///
    /// // Wide spacing
    /// Graphics.setTextTracking(2)
    /// Graphics.drawText("W i d e", at: Point(x: 10, y: 50))
    /// ```
    static func setTextTracking(_ tracking: Int32) {
        graphicsAPI.setTextTracking(tracking)
    }

    /// Get current character spacing (tracking)
    ///
    /// Returns the current tracking value set with setTextTracking.
    ///
    /// - Returns: Current tracking in pixels
    ///
    /// From Playdate SDK:
    /// > "Gets the tracking used when drawing text."
    ///
    /// Example:
    /// ```swift
    /// Graphics.setTextTracking(2)
    /// let tracking = Graphics.getTextTracking()
    /// print("Current tracking: \(tracking)px") // 2
    /// ```
    static func getTextTracking() -> Int32 {
        return graphicsAPI.getTextTracking()
    }

    /// Set line spacing (leading) adjustment for text rendering
    ///
    /// Sets additional line spacing (leading) beyond the font's built-in leading.
    /// This affects multi-line text rendering.
    ///
    /// - Parameter leading: Additional line spacing in pixels (can be negative)
    ///
    /// From Playdate SDK:
    /// > "Sets the leading adjustment (added to the leading specified in the font)
    /// > to use when drawing text."
    ///
    /// Example:
    /// ```swift
    /// // Tight line spacing
    /// Graphics.setTextLeading(-2)
    ///
    /// // Normal line spacing
    /// Graphics.setTextLeading(0)
    ///
    /// // Loose line spacing
    /// Graphics.setTextLeading(5)
    ///
    /// // Draw multi-line text
    /// Graphics.drawText(
    ///     "Line 1\nLine 2\nLine 3",
    ///     in: Rect(x: 10, y: 10, width: 200, height: 100),
    ///     wrap: .word
    /// )
    /// ```
    static func setTextLeading(_ leading: Int32) {
        graphicsAPI.setTextLeading(leading)
    }

    /// Execute drawing with temporary tracking
    ///
    /// - Parameters:
    ///   - tracking: Temporary tracking value
    ///   - draw: Closure to execute with tracking
    /// - Throws: Rethrows any error from the closure
    ///
    /// Example:
    /// ```swift
    /// try Graphics.withTracking(2) {
    ///     Graphics.drawText("Wide text", at: Point(x: 10, y: 10))
    /// }
    /// // Previous tracking is NOT restored
    /// ```
    static func withTracking<T>(_ tracking: Int32, _ draw: () throws -> T) rethrows -> T {
        let previous = getTextTracking()
        setTextTracking(tracking)
        defer { setTextTracking(previous) }
        return try draw()
    }

    /// Execute drawing with temporary leading
    ///
    /// - Parameters:
    ///   - leading: Temporary leading value
    ///   - draw: Closure to execute with leading
    /// - Throws: Rethrows any error from the closure
    ///
    /// Example:
    /// ```swift
    /// try Graphics.withLeading(5) {
    ///     Graphics.drawText(
    ///         "Multi\nline\ntext",
    ///         in: rect,
    ///         wrap: .word
    ///     )
    /// }
    /// ```
    static func withLeading<T>(_ leading: Int32, _ draw: () throws -> T) rethrows -> T {
        // Note: C API doesn't have getTextLeading, so we can't restore
        setTextLeading(leading)
        return try draw()
    }
}

// MARK: - Convenience Text Drawing Extensions

public extension Graphics {
    /// Draw text with all formatting options
    ///
    /// Comprehensive text drawing with font, tracking, and position.
    ///
    /// - Parameters:
    ///   - text: Text to draw
    ///   - position: Position to draw at
    ///   - font: Font to use (nil for current)
    ///   - tracking: Character spacing (nil for current)
    ///   - encoding: String encoding
    /// - Returns: Width of drawn text
    ///
    /// Example:
    /// ```swift
    /// Graphics.drawText(
    ///     "Formatted",
    ///     at: Point(x: 10, y: 10),
    ///     font: myFont,
    ///     tracking: 2
    /// )
    /// ```
    @discardableResult
    static func drawText(
        _ text: String,
        at position: Point,
        font: Font? = nil,
        tracking: Int32? = nil,
        encoding: StringEncoding = .utf8
    ) -> Int32 {
        // Set font if provided
        if let font = font {
            setFont(font)
        }

        // Set tracking if provided
        let previousTracking: Int32?
        if let tracking = tracking {
            previousTracking = getTextTracking()
            setTextTracking(tracking)
        } else {
            previousTracking = nil
        }

        // Draw text
        let width = drawText(text, at: position, encoding: encoding)

        // Restore tracking if changed
        if let previous = previousTracking {
            setTextTracking(previous)
        }

        return width
    }

    /// Draw text in rect with all formatting options
    ///
    /// - Parameters:
    ///   - text: Text to draw
    ///   - rect: Rectangle to draw in
    ///   - wrap: Wrapping mode
    ///   - align: Text alignment
    ///   - font: Font to use (nil for current)
    ///   - tracking: Character spacing (nil for current)
    ///   - leading: Line spacing (nil for current)
    ///   - encoding: String encoding
    ///
    /// Example:
    /// ```swift
    /// Graphics.drawText(
    ///     "Long text...",
    ///     in: Rect(x: 10, y: 10, width: 200, height: 100),
    ///     wrap: .word,
    ///     align: .center,
    ///     font: myFont,
    ///     tracking: 1,
    ///     leading: 2
    /// )
    /// ```
    static func drawText(
        _ text: String,
        in rect: Rect,
        wrap: TextWrappingMode = .word,
        align: TextAlignment = .left,
        font: Font? = nil,
        tracking: Int32? = nil,
        leading: Int32? = nil,
        encoding: StringEncoding = .utf8
    ) {
        // Set font if provided
        if let font = font {
            setFont(font)
        }

        // Set tracking if provided
        let previousTracking: Int32?
        if let tracking = tracking {
            previousTracking = getTextTracking()
            setTextTracking(tracking)
        } else {
            previousTracking = nil
        }

        // Set leading if provided
        if let leading = leading {
            setTextLeading(leading)
        }

        // Draw text
        drawText(text, in: rect, wrap: wrap, align: align, encoding: encoding)

        // Restore tracking if changed
        if let previous = previousTracking {
            setTextTracking(previous)
        }

        // Note: Can't restore leading (no getter in C API)
    }
}

// MARK: - Text Layout Helpers

public extension Graphics {
    /// Calculate text bounds for given string
    ///
    /// Returns the rectangle that would contain the text when drawn.
    ///
    /// - Parameters:
    ///   - text: Text to measure
    ///   - position: Position where text would be drawn
    ///   - font: Font to measure with (nil for current - requires Font parameter)
    ///   - tracking: Character spacing
    ///   - encoding: String encoding
    /// - Returns: Rectangle containing the text
    ///
    /// Example:
    /// ```swift
    /// let bounds = Graphics.getTextBounds(
    ///     "Hello",
    ///     at: Point(x: 100, y: 50),
    ///     font: myFont
    /// )
    /// // Draw border around text
    /// Graphics.drawRect(bounds, color: .black)
    /// Graphics.drawText("Hello", at: Point(x: 100, y: 50))
    /// ```
    static func getTextBounds(
        _ text: String,
        at position: Point,
        font: Font,
        tracking: Int32 = 0,
        encoding: StringEncoding = .utf8
    ) -> Rect {
        let width = font.getTextWidth(text, encoding: encoding, tracking: tracking)
        let height = font.height

        return Rect(
            x: position.x,
            y: position.y,
            width: width,
            height: height
        )
    }

    /// Calculate text bounds for wrapped text
    ///
    /// - Parameters:
    ///   - text: Text to measure
    ///   - rect: Rectangle to fit text in
    ///   - font: Font to measure with
    ///   - wrap: Wrapping mode
    ///   - tracking: Character spacing
    ///   - extraLeading: Additional line spacing
    ///   - encoding: String encoding
    /// - Returns: Rectangle containing the wrapped text
    ///
    /// Example:
    /// ```swift
    /// let container = Rect(x: 10, y: 10, width: 200, height: 200)
    /// let bounds = Graphics.getTextBounds(
    ///     "Long text...",
    ///     in: container,
    ///     font: myFont,
    ///     wrap: .word
    /// )
    /// print("Text height: \(bounds.height)")
    /// ```
    static func getTextBounds(
        _ text: String,
        in rect: Rect,
        font: Font,
        wrap: TextWrappingMode = .word,
        tracking: Int32 = 0,
        extraLeading: Int32 = 0,
        encoding: StringEncoding = .utf8
    ) -> Rect {
        let height = font.getTextHeight(
            text,
            forMaxWidth: rect.width,
            encoding: encoding,
            wrap: wrap,
            tracking: tracking,
            extraLeading: extraLeading
        )

        return Rect(
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: height
        )
    }
}
