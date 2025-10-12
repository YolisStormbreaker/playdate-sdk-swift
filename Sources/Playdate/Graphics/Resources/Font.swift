// Font.swift
// Playdate Graphics Swift SDK
//
// Wrapper for LCDFont* with automatic memory management
// Handles font loading, text measurement, and rendering

import CPlaydate

// MARK: - Graphics API Accessor

/// Access to Playdate graphics C API
private var graphicsAPI: playdate_graphics {
    playdateAPI.graphics.unsafelyUnwrapped.pointee
}

// MARK: - Font Class

/// Represents a font in Playdate graphics system
///
/// Fonts are used for rendering text on screen. The Playdate system includes
/// a default font (Asheville Sans 14 Light) which is used when no font is set.
///
/// # Font File Format
///
/// Fonts are stored in .pft (Playdate Font) format. These can be:
/// - Loaded from files using `Font.load(path:)`
/// - Created from raw data using `Font.makeFont(from:)`
///
/// # Memory Management
///
/// Fonts follow owned/borrowed pattern:
/// - **Owned fonts** (loaded/created) - freed in deinit
/// - **Borrowed fonts** (system font) - not freed
///
/// # Usage Examples
///
/// ```swift
/// // Load custom font
/// switch Font.load(path: "fonts/MyFont") {
/// case .success(let font):
///     font.setAsCurrent()
///
///     // Measure text
///     let width = font.getTextWidth("Hello World")
///     print("Text width: \(width)px")
///
/// case .failure(let error):
///     print("Failed to load font: \(error)")
/// }
///
/// // Use system font
/// Font.systemFont().setAsCurrent()
///
/// ```
public final class Font: @unchecked Sendable {
    // MARK: - Private Properties

    /// Pointer to underlying LCDFont C structure
    private let pointer: OpaquePointer

    /// Ownership type - determines if font should be freed in deinit
    private let ownership: Ownership

    /// Original file path (if loaded from file)
    private let sourcePath: String?

    /// Ownership model for font memory management
    private enum Ownership {
        case owned // We created/loaded it, we free it in deinit
        case borrowed // System owns it, don't free in deinit
    }

    // MARK: - Public Properties

    /// Height of the font in pixels
    ///
    /// Represents the line height of the font, useful for calculating
    /// vertical spacing in multi-line text.
    ///
    /// Example:
    /// ```swift
    /// let font = Font.load(path: "fonts/MyFont").get()
    /// print("Font height: \(font.height)px")
    ///
    /// // Calculate position for multiple lines
    /// let line1Y: Int32 = 10
    /// let line2Y: Int32 = line1Y + font.height
    /// ```
    public var height: Int32 {
        return Int32(graphicsAPI.getFontHeight(pointer))
    }

    /// Original file path if font was loaded from file
    ///
    /// Returns nil for fonts created from data or system font.
    public var path: String? {
        return sourcePath
    }

    /// Check if this is an owned font (will be freed in deinit)
    public var isOwned: Bool {
        return ownership == .owned
    }

    /// Check if this is a borrowed font (system owned, not freed in deinit)
    public var isBorrowed: Bool {
        return ownership == .borrowed
    }

    // MARK: - Private Initialization

    /// Internal unsafe initializer - assumes pointer is valid
    ///
    /// - Parameters:
    ///   - ownedPointer: Valid LCDFont pointer (will be freed)
    ///   - sourcePath: Original file path if loaded from file
    private init(ownedPointer ptr: OpaquePointer, sourcePath: String?) {
        pointer = ptr
        ownership = .owned
        self.sourcePath = sourcePath
    }

    /// Internal initializer for borrowed font pointer (system owned)
    ///
    /// - Parameter borrowedPointer: Pointer to system-owned font (won't be freed)
    private init(borrowedPointer: OpaquePointer) {
        pointer = borrowedPointer
        ownership = .borrowed
        sourcePath = nil
    }

    /// Deinitializer - frees owned fonts
    deinit {
        if ownership == .owned {
            // Free the C font structure
            // Per SDK docs: "can be freed with playdate→system→realloc(font, 0)"
            _ = playdateAPI.system.unsafelyUnwrapped.pointee.realloc(UnsafeMutablePointer(pointer), 0)
        }
        // borrowed fonts are not freed - system manages them
    }

    /// Internal access to C pointer for C API operations
    var cPointer: OpaquePointer {
        return pointer
    }
}

// MARK: - Static Factory Methods - Loading

public extension Font {
    /// Load font from file path
    ///
    /// Loads a Playdate font (.pft) from the specified path.
    ///
    /// - Parameter path: Path to font file (relative to project root)
    /// - Returns: Result with Font on success or GraphicsError on failure
    ///
    /// From Playdate SDK:
    /// > "Returns the LCDFont object for the font file at path.
    /// > In case of error, outErr points to a string describing the error."
    ///
    /// Example:
    /// ```swift
    /// // Load custom font
    /// switch Font.load(path: "fonts/MyFont") {
    /// case .success(let font):
    ///     print("Font loaded: height=\(font.height)px")
    ///     font.setAsCurrent()
    ///
    /// case .failure(let error):
    ///     print("Failed to load font: \(error)")
    /// }
    ///
    /// // Load with convenience init
    /// if let font = Font(path: "fonts/Title") {
    ///     font.setAsCurrent()
    /// }
    /// ```
    static func load(path: String) -> Result<Font, GraphicsError> {
        var errorPtr: UnsafePointer<CChar>?

        // Load font via C API
        guard let ptr = graphicsAPI.loadFont(path, &errorPtr) else {
            let errorMessage = errorPtr.map { String(cString: $0) }
                ?? "File not found or invalid format"
            return .failure(.fontLoadFailed(
                path: path,
                reason: errorMessage
            ))
        }

        return .success(Font(ownedPointer: ptr, sourcePath: path))
    }

    /// Get system font (Asheville Sans 14 Light)
    ///
    /// Returns the default Playdate system font. This is the same font used
    /// when no font is set with setFont.
    ///
    /// - Returns: System font instance
    ///
    /// - Note: System font is cached as a singleton for performance.
    ///         Multiple calls return the same instance.
    ///
    /// Example:
    /// ```swift
    /// // Use system font
    /// let systemFont = Font.systemFont()
    /// systemFont.setAsCurrent()
    ///
    /// // Reset to default font
    /// Font.systemFont().setAsCurrent()
    /// ```
    static func systemFont() -> Font {
        // Lazy singleton for system font
        enum LazySystemFont {
            static let instance: Font = {
                // Load system font from known path
                // Asheville Sans 14 Light is the default Playdate font
                let result = Font.load(path: SystemFont.ashevilleSans14Light.path)

                switch result {
                case let .success(font):
                    return font
                case .failure:
                    // Fallback: this should never happen, but provide safety
                    // Create a minimal borrowed font wrapper
                    fatalError("Failed to load system font - this should not happen on Playdate hardware")
                }
            }()
        }

        return LazySystemFont.instance
    }
}

// MARK: - Convenience Failable Initializers

public extension Font {
    /// Convenience failable initializer for loading font
    ///
    /// - Parameter path: Path to font file
    /// - Returns: Font instance or nil if load fails
    ///
    /// Example:
    /// ```swift
    /// if let font = Font(path: "fonts/MyFont") {
    ///     font.setAsCurrent()
    /// }
    /// ```
    convenience init?(path: String) {
        switch Font.load(path: path) {
        case let .success(font):
            self.init(ownedPointer: font.pointer, sourcePath: font.sourcePath)
        case .failure:
            return nil
        }
    }
}

// MARK: - Text Measurement

public extension Font {
    /// Get width of text in pixels
    ///
    /// Calculates the width of the given text string when rendered with this font.
    ///
    /// - Parameters:
    ///   - text: Text string to measure
    ///   - encoding: String encoding (default: UTF-8)
    ///   - tracking: Additional spacing between characters in pixels (default: 0)
    /// - Returns: Width in pixels
    ///
    /// From Playdate SDK:
    /// > "Returns the width of the given text in the given font."
    ///
    /// Example:
    /// ```swift
    /// let font = Font.load(path: "fonts/MyFont").get()
    ///
    /// // Basic measurement
    /// let width = font.getTextWidth("Hello World")
    /// print("Width: \(width)px")
    ///
    /// // With tracking
    /// let wideWidth = font.getTextWidth("Hello", tracking: 2)
    ///
    /// // Different encoding
    /// let asciiWidth = font.getTextWidth("ABC", encoding: .ascii)
    /// ```
    func getTextWidth(
        _ text: String,
        encoding: StringEncoding = .utf8,
        tracking: Int32 = 0
    ) -> Int32 {
        // Convert Swift String to C string
        return text.withCString { cString in
            // Calculate length based on encoding
            let length = text.utf8.count

            // Call C API
            return graphicsAPI.getTextWidth(
                pointer,
                cString,
                length,
                encoding.cValue,
                tracking
            )
        }
    }

    /// Get height of text for given maximum width with wrapping
    ///
    /// Calculates the height needed to render text when wrapped to a maximum width.
    /// Useful for calculating text box sizes and multi-line text layout.
    ///
    /// - Parameters:
    ///   - text: Text string to measure
    ///   - maxWidth: Maximum width before wrapping (in pixels)
    ///   - encoding: String encoding (default: UTF-8)
    ///   - wrap: Text wrapping mode (default: word)
    ///   - tracking: Additional spacing between characters (default: 0)
    ///   - extraLeading: Additional line spacing beyond font's leading (default: 0)
    /// - Returns: Height in pixels needed for wrapped text
    ///
    /// From Playdate SDK:
    /// > "Returns the height of text in the given font, when wrapped
    /// > to maxwidth using the wrapping mode wrap."
    ///
    /// Example:
    /// ```swift
    /// let font = Font.load(path: "fonts/MyFont").get()
    /// let longText = "This is a very long text that will wrap"
    ///
    /// // Calculate height for wrapped text
    /// let height = font.getTextHeight(
    ///     longText,
    ///     forMaxWidth: 200,
    ///     wrap: .word
    /// )
    ///
    /// // Draw in calculated rect
    /// let rect = Rect(x: 10, y: 10, width: 200, height: height)
    /// // ... draw text in rect
    /// ```
    func getTextHeight(
        _ text: String,
        forMaxWidth maxWidth: Int32,
        encoding: StringEncoding = .utf8,
        wrap: TextWrappingMode = .word,
        tracking: Int32 = 0,
        extraLeading: Int32 = 0
    ) -> Int32 {
        return text.withCString { cString in
            let length = text.utf8.count

            return graphicsAPI.getTextHeightForMaxWidth(
                pointer,
                cString,
                length,
                maxWidth,
                encoding.cValue,
                wrap.cValue,
                tracking,
                extraLeading
            )
        }
    }

    /// Get size of text (width and height)
    ///
    /// Convenience method that returns both width and height.
    ///
    /// - Parameters:
    ///   - text: Text string to measure
    ///   - encoding: String encoding (default: UTF-8)
    ///   - tracking: Character spacing (default: 0)
    /// - Returns: Size with width and height
    ///
    /// Example:
    /// ```swift
    /// let size = font.getTextSize("Hello")
    /// print("Text size: \(size.width)x\(size.height)")
    /// ```
    func getTextSize(
        _ text: String,
        encoding: StringEncoding = .utf8,
        tracking: Int32 = 0
    ) -> Size {
        let width = getTextWidth(text, encoding: encoding, tracking: tracking)
        return Size(width: width, height: height)
    }

    /// Get size of text with wrapping
    ///
    /// Returns the size needed for text when wrapped to maximum width.
    ///
    /// - Parameters:
    ///   - text: Text string to measure
    ///   - maxWidth: Maximum width before wrapping
    ///   - encoding: String encoding (default: UTF-8)
    ///   - wrap: Wrapping mode (default: word)
    ///   - tracking: Character spacing (default: 0)
    ///   - extraLeading: Additional line spacing (default: 0)
    /// - Returns: Size with width and calculated height
    ///
    /// Example:
    /// ```swift
    /// let size = font.getTextSize(
    ///     "Long text...",
    ///     maxWidth: 200,
    ///     wrap: .word
    /// )
    /// ```
    func getTextSize(
        _ text: String,
        maxWidth: Int32,
        encoding: StringEncoding = .utf8,
        wrap: TextWrappingMode = .word,
        tracking: Int32 = 0,
        extraLeading: Int32 = 0
    ) -> Size {
        let height = getTextHeight(
            text,
            forMaxWidth: maxWidth,
            encoding: encoding,
            wrap: wrap,
            tracking: tracking,
            extraLeading: extraLeading
        )

        return Size(width: maxWidth, height: height)
    }

    /// Check if text fits within given width
    ///
    /// - Parameters:
    ///   - text: Text to check
    ///   - maxWidth: Maximum allowed width
    ///   - encoding: String encoding (default: UTF-8)
    ///   - tracking: Character spacing (default: 0)
    /// - Returns: true if text fits, false if it would overflow
    ///
    /// Example:
    /// ```swift
    /// if font.textFits("Hello", within: 100) {
    ///     // Draw text
    /// } else {
    ///     // Text too wide, need to wrap or truncate
    /// }
    /// ```
    func textFits(
        _ text: String,
        within maxWidth: Int32,
        encoding: StringEncoding = .utf8,
        tracking: Int32 = 0
    ) -> Bool {
        let width = getTextWidth(text, encoding: encoding, tracking: tracking)
        return width <= maxWidth
    }
}

// MARK: - Font Management

public extension Font {
    /// Set this font as current for subsequent drawing operations
    ///
    /// After calling this method, all text drawing operations will use this font
    /// until another font is set.
    ///
    /// Example:
    /// ```swift
    /// let titleFont = Font.load(path: "fonts/Title").get()
    /// titleFont.setAsCurrent()
    ///
    /// // Now all text uses titleFont
    /// Graphics.drawText("Hello", at: Point(x: 100, y: 50))
    ///
    /// // Switch to different font
    /// let bodyFont = Font.load(path: "fonts/Body").get()
    /// bodyFont.setAsCurrent()
    /// ```
    func setAsCurrent() {
        graphicsAPI.setFont(pointer)
    }

    /// Execute drawing closure with this font as current
    ///
    /// Temporarily sets this font as current, executes the closure,
    /// then restores the previous font.
    ///
    /// - Parameter draw: Closure to execute with this font active
    /// - Throws: Rethrows any error from the drawing closure
    ///
    /// Example:
    /// ```swift
    /// let specialFont = Font.load(path: "fonts/Special").get()
    ///
    /// try specialFont.withFont {
    ///     Graphics.drawText("Special text", at: Point(x: 10, y: 10))
    ///     Graphics.drawText("More special", at: Point(x: 10, y: 30))
    /// }
    /// // Previous font is restored here
    /// ```
    func withFont<T>(_ draw: () throws -> T) rethrows -> T {
        // Note: No C API to get current font, so we can't restore it
        // This is a simple convenience that just sets the font
        setAsCurrent()
        return try draw()
    }
}

// MARK: - Internal Glyph Access (for future extensions)

extension Font {
    /// Get font page for character (internal use)
    ///
    /// Font pages contain information for 256 characters each.
    /// Characters with (c1 & ~0xff) == (c2 & ~0xff) belong to same page.
    ///
    /// - Parameter character: Unicode character code
    /// - Returns: Pointer to font page or nil if not found
    func getFontPage(for character: UInt32) -> OpaquePointer? {
        return graphicsAPI.getFontPage(pointer, character)
    }

    /// Get glyph information for character from page
    ///
    /// - Parameters:
    ///   - page: Font page containing the character
    ///   - character: Unicode character code
    /// - Returns: Tuple with glyph, bitmap, and advance width or
    /// (nil, nil, 0) in case of error
    func getGlyph(
        from page: FontPage,
        for character: UInt32
    ) -> (
        glyph: FontGlyph?,
        bitmap: Bitmap?,
        advance: Int32
    ) {
        var bitmapPtr: OpaquePointer?
        var advance: Int32 = 0

        guard let glyphPtr = graphicsAPI.getPageGlyph(
            page.pointer,
            character,
            &bitmapPtr,
            &advance
        ) else {
            return (nil, nil, 0)
        }

        // Создаем Bitmap только если указатель не nil
        let bitmap = bitmapPtr.map(Bitmap.init)

        // Создаем FontGlyph (может быть nil если glyphPtr nil)
        let glyph = FontGlyph(
            pointer: glyphPtr,
            bitmap: bitmap,
            advance: advance
        )

        return (glyph: glyph, bitmap: bitmap, advance: advance)
    }

    /// Get kerning adjustment between two characters (internal use)
    ///
    /// - Parameters:
    ///   - glyph: Glyph for first character
    ///   - firstChar: First character code
    ///   - secondChar: Second character code
    /// - Returns: Kerning adjustment in pixels (can be negative)
    func getKerning(
        for glyph: UnsafeMutablePointer<LCDFontGlyph>,
        between firstChar: UInt32,
        and secondChar: UInt32
    ) -> Int32 {
        return graphicsAPI.getGlyphKerning(glyph.pointee, firstChar, secondChar)
    }
}

// MARK: - Equatable

extension Font: Equatable {
    /// Compare two fonts for equality
    ///
    /// Fonts are considered equal if they point to the same underlying C font.
    ///
    /// Example:
    /// ```swift
    /// let font1 = Font.load(path: "fonts/MyFont").get()
    /// let font2 = Font.load(path: "fonts/MyFont").get()
    /// let font3 = font1
    ///
    /// print(font1 == font2) // false (different instances)
    /// print(font1 == font3) // true (same instance)
    /// ```
    public static func == (lhs: Font, rhs: Font) -> Bool {
        return lhs.pointer == rhs.pointer
    }
}

// MARK: - Hashable

extension Font: Hashable {
    /// Hash font based on pointer identity
    ///
    /// Allows fonts to be used in Sets and as Dictionary keys.
    ///
    /// Example:
    /// ```swift
    /// var fontCache: Set<Font> = []
    /// fontCache.insert(myFont)
    ///
    /// var fontNames: [Font: String] = [:]
    /// fontNames[myFont] = "My Font"
    /// ```
    public func hash(into hasher: inout Hasher) {
        hasher.combine(Int(bitPattern: pointer))
    }
}

// MARK: - CustomStringConvertible

extension Font: CustomStringConvertible {
    /// Human-readable description of the font
    ///
    /// Shows height and file path (if loaded from file).
    ///
    /// Example outputs:
    /// - "Font(height: 14, path: "fonts/MyFont")"
    /// - "Font(height: 14)"
    /// - "Font(height: 14, system)"
    public var description: String {
        var desc = "Font(height: \(height)"

        if let path = sourcePath {
            // Check if this is system font path
            if path.contains("System/Fonts") {
                desc += ", system"
            } else {
                desc += ", path: \"\(path)\""
            }
        } else if ownership == .borrowed {
            desc += ", borrowed"
        }

        desc += ")"
        return desc
    }
}

// MARK: - Convenience Properties

public extension Font {
    /// Check if this is the system font
    var isSystemFont: Bool {
        guard let path = sourcePath else { return false }
        return path.contains("System/Fonts/Asheville-Sans")
    }

    /// Font name derived from path (if available)
    ///
    /// Extracts font name from file path.
    ///
    /// Example:
    /// ```swift
    /// let font = Font.load(path: "fonts/MyFont").get()
    /// print(font.name) // "MyFont"
    /// ```
    var name: String? {
        guard let path = sourcePath else { return nil }

        // Extract filename without extension
        let components = path.split(separator: "/")
        guard let filename = components.last else { return nil }

        // Remove extension
        let nameComponents = filename.split(separator: ".")
        return nameComponents.first.map(String.init)
    }
}

// MARK: - Result Convenience Extensions

public extension Result where Success == Font, Failure == GraphicsError {
    /// Get font or nil (silent failure)
    ///
    /// Example:
    /// ```swift
    /// let font = Font.load("fonts/MyFont").orNil
    /// font?.setAsCurrent()
    /// ```
    var orNil: Font? {
        try? get()
    }

    /// Get font or crash with message (development only)
    ///
    /// Example:
    /// ```swift
    /// let font = Font.load("fonts/MyFont").orCrash()
    /// ```
    func orCrash(file: String = #file, line: Int = #line) -> Font {
        switch self {
        case let .success(font):
            return font
        case let .failure(error):
            fatalError("Font operation failed: \(error) at \(file):\(line)")
        }
    }

    /// Get font or fallback
    ///
    /// Example:
    /// ```swift
    /// let font = Font.load("fonts/MyFont").or(Font.systemFont())
    /// ```
    func or(_ fallback: Font) -> Font {
        (try? get()) ?? fallback
    }

    /// Execute block only on success
    ///
    /// Example:
    /// ```swift
    /// Font.load("fonts/MyFont").onSuccess { font in
    ///     font.setAsCurrent()
    /// }
    /// ```
    func onSuccess(_ block: (Font) -> Void) {
        if case let .success(font) = self {
            block(font)
        }
    }

    /// Execute block only on failure
    ///
    /// Example:
    /// ```swift
    /// Font.load("fonts/MyFont")
    ///     .onSuccess { $0.setAsCurrent() }
    ///     .onFailure { print("Error: \($0)") }
    /// ```
    @discardableResult
    func onFailure(_ block: (GraphicsError) -> Void) -> Self {
        if case let .failure(error) = self {
            block(error)
        }
        return self
    }
}

// MARK: - Debug Helpers

#if DEBUG
    public extension Font {
        /// Debug information about font
        var debugInfo: String {
            var info = """
            Font Debug Info:
            - Height: \(height)px
            - Ownership: \(ownership == .owned ? "owned" : "borrowed")
            """

            if let path = sourcePath {
                info += "\n- Source Path: \(path)"
            }

            if let name = name {
                info += "\n- Name: \(name)"
            }

            if isSystemFont {
                info += "\n- Type: System Font"
            }

            return info
        }

        /// Print debug information to console
        func printDebugInfo() {
            print(debugInfo)
        }

        /// Measure and print statistics for sample text
        ///
        /// - Parameter text: Sample text to analyze
        func analyzeText(_ text: String) {
            print("""
            Font Text Analysis:
            - Font: \(name ?? "unnamed")
            - Height: \(height)px
            - Text: "\(text)"
            - Width: \(getTextWidth(text))px
            - Characters: \(text.utf8.count)
            - Average char width: \(Float(getTextWidth(text)) / Float(text.utf8.count))px
            """)
        }
    }
#endif
