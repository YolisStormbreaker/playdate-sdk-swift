//
// SystemFonts.swift
// Playdate Graphics SDK
//
// Playdate System Fonts
// Provides convenient access to built-in console fonts
//

import CPlaydate

// MARK: - System Font Enum

/// Playdate System Fonts
///
/// All fonts built into Playdate OS and available in `/System/Fonts/`.
/// Using system fonts ensures UI consistency and doesn't require
/// packaging fonts into the .pdx file.
///
/// Example:
/// ```swift
/// // Load system font
/// let font = Font.loadSystem(.ashevilleSans14Bold)
///
/// // Use with error handling
/// switch Font.loadSystem(.roobert20Medium) {
/// case .success(let font):
///     font.setAsCurrent()
///     Graphics.drawText("Title", at: Point(x: 10, y: 10))
/// case .failure(let error):
///     print("Failed to load font: \(error)")
/// }
/// ```
public enum SystemFont: String, CaseIterable {
    // MARK: - Asheville Sans Family

    /// Asheville Sans 14pt Bold
    ///
    /// Bold medium-sized font. Suitable for headings,
    /// buttons, and accents.
    ///
    /// - Size: 14pt
    /// - Weight: Bold
    /// - Family: Asheville Sans
    case ashevilleSans14Bold = "Asheville-Sans-14-Bold"

    /// Asheville Sans 14pt Light (Oblique/Italic)
    ///
    /// Light oblique font. Suitable for quotes, notes,
    /// and italics.
    ///
    /// - Size: 14pt
    /// - Weight: Light
    /// - Style: Oblique (Italic)
    /// - Family: Asheville Sans
    case ashevilleSans14LightOblique = "Asheville-Sans-14-Light-Oblique"

    /// Asheville Sans 14pt Light
    ///
    /// Standard Playdate system font. Used by default
    /// if no font is explicitly set. Optimal for body text.
    ///
    /// - Size: 14pt
    /// - Weight: Light
    /// - Family: Asheville Sans
    /// - Note: Default system font
    case ashevilleSans14Light = "Asheville-Sans-14-Light"

    /// Asheville Sans 24pt Light
    ///
    /// Large light font. Suitable for big headings
    /// and launch screens.
    ///
    /// - Size: 24pt
    /// - Weight: Light
    /// - Family: Asheville Sans
    case ashevilleSans24Light = "Asheville-Sans-24-Light"

    // MARK: - Roobert Family

    /// Roobert 10pt Bold
    ///
    /// Small bold font. Suitable for labels, tags,
    /// and small headings.
    ///
    /// - Size: 10pt
    /// - Weight: Bold
    /// - Family: Roobert
    case roobert10Bold = "Roobert-10-Bold"

    /// Roobert 11pt Bold
    ///
    /// Small bold font. Suitable for navigation,
    /// menu buttons, and UI elements.
    ///
    /// - Size: 11pt
    /// - Weight: Bold
    /// - Family: Roobert
    case roobert11Bold = "Roobert-11-Bold"

    /// Roobert 11pt Medium
    ///
    /// Small medium-weight font. Suitable for
    /// body text in compact interfaces.
    ///
    /// - Size: 11pt
    /// - Weight: Medium
    /// - Family: Roobert
    case roobert11Medium = "Roobert-11-Medium"

    /// Roobert 20pt Medium
    ///
    /// Large medium-weight font. Suitable for
    /// headings and important messages.
    ///
    /// - Size: 20pt
    /// - Weight: Medium
    /// - Family: Roobert
    case roobert20Medium = "Roobert-20-Medium"

    /// Roobert 24pt Medium
    ///
    /// Very large medium-weight font. Suitable for
    /// main headings and splash screens.
    ///
    /// - Size: 24pt
    /// - Weight: Medium
    /// - Family: Roobert
    case roobert24Medium = "Roobert-24-Medium"

    // MARK: - Path Properties

    /// Full path to font file in Playdate system
    ///
    /// All system fonts are located in `/System/Fonts/`.
    ///
    /// Example:
    /// ```swift
    /// let font = SystemFont.ashevilleSans14Bold
    /// print(font.path)  // "/System/Fonts/Asheville-Sans-14-Bold.pft"
    /// ```
    public var path: String {
        return "/System/Fonts/\(rawValue).pft"
    }

    /// Font filename with extension
    ///
    /// Example:
    /// ```swift
    /// let font = SystemFont.roobert20Medium
    /// print(font.filename)  // "Roobert-20-Medium.pft"
    /// ```
    public var filename: String {
        return "\(rawValue).pft"
    }

    /// Display name of font (for UI)
    ///
    /// Example:
    /// ```swift
    /// let font = SystemFont.ashevilleSans14Bold
    /// print(font.displayName)  // "Asheville Sans 14 Bold"
    /// ```
    public var displayName: String {
        return rawValue.replacing("-", with: " ")
    }

    // MARK: - Font Properties

    /// Font family
    public var family: FontFamily {
        if rawValue.hasPrefix("Asheville") {
            return .ashevilleSans
        } else {
            return .roobert
        }
    }

    /// Font size in points
    public var pointSize: Int {
        // Extract number from name (e.g., "Roobert-20-Medium" -> 20)
        let components = rawValue.split(by: "-")
        for component in components {
            if let size = parseNumber(component) {
                return size
            }
        }
        return 14 // default
    }

    /// Font weight
    public var weight: FontWeight {
        let lower = rawValue.lowercasedASCII()
        if lower.contains("bold") {
            return .bold
        } else if lower.contains("medium") {
            return .medium
        } else {
            return .light
        }
    }

    /// Font style
    public var style: FontStyle {
        let lower = rawValue.lowercasedASCII()
        if lower.contains("oblique") || lower.contains("italic") {
            return .oblique
        } else {
            return .regular
        }
    }

    // MARK: - Helper

    private func parseNumber(_ text: String) -> Int? {
        let bytes = Array(text.utf8)
        var result = 0
        var hasDigits = false

        for byte in bytes {
            if byte >= 48 && byte <= 57 { // 0-9
                result = result * 10 + Int(byte - 48)
                hasDigits = true
            }
        }

        return hasDigits ? result : nil
    }
}

// MARK: - Font Family Enum

/// System font family
public enum FontFamily: String {
    /// Asheville Sans - standard Playdate family
    case ashevilleSans = "Asheville Sans"

    /// Roobert - alternative family
    case roobert = "Roobert"
}

// MARK: - Font Weight Enum

/// Font weight (boldness)
public enum FontWeight: String {
    case light = "Light"
    case medium = "Medium"
    case bold = "Bold"
}

// MARK: - Font Style Enum

/// Font style
public enum FontStyle: String {
    case regular = "Regular"
    case oblique = "Oblique"
}

// MARK: - Font Extension for System Fonts

public extension Font {
    /// Load Playdate system font
    ///
    /// Loads a built-in system font from `/System/Fonts/`.
    /// Guaranteed to be available on all Playdate devices.
    ///
    /// - Parameter systemFont: System font to load
    /// - Returns: Result with loaded font or error
    ///
    /// Example:
    /// ```swift
    /// // Simple loading
    /// let font = try! Font.loadSystem(.ashevilleSans14Bold).get()
    /// font.setAsCurrent()
    ///
    /// // With error handling
    /// switch Font.loadSystem(.roobert20Medium) {
    /// case .success(let font):
    ///     Graphics.setFont(font)
    ///     Graphics.drawText("Title", at: Point(x: 10, y: 10))
    /// case .failure(let error):
    ///     print("Font load error: \(error)")
    /// }
    ///
    /// // Using default font
    /// let defaultFont = Font.loadSystem(.default)
    /// ```
    static func loadSystem(_ systemFont: SystemFont) -> Result<Font, GraphicsError> {
        return Font.load(path: systemFont.path)
    }

    /// Load system font and immediately set as current
    ///
    /// Convenient method for simultaneous loading and activation of font.
    ///
    /// - Parameter systemFont: System font to load
    /// - Returns: Result with loaded font or error
    ///
    /// Example:
    /// ```swift
    /// // Load and set in one command
    /// _ = Font.loadSystemAndSetCurrent(.ashevilleSans14Bold)
    ///
    /// // With error handling
    /// switch Font.loadSystemAndSetCurrent(.roobert24Medium) {
    /// case .success(let font):
    ///     Graphics.drawText("Big Title", at: Point(x: 10, y: 10))
    /// case .failure:
    ///     // Fallback to default font
    ///     Graphics.setDefaultFont()
    /// }
    /// ```
    static func loadSystemAndSetCurrent(_ systemFont: SystemFont) -> Result<Font, GraphicsError> {
        let result = loadSystem(systemFont)
        if case let .success(font) = result {
            font.setAsCurrent()
        }
        return result
    }
}

// MARK: - SystemFont Convenience Extensions

public extension SystemFont {
    /// Standard Playdate system font (Asheville Sans 14 Light)
    ///
    /// This is the font used by default in the system.
    static var `default`: SystemFont {
        return .ashevilleSans14Light
    }

    /// Get all fonts of specific family
    ///
    /// - Parameter family: Font family
    /// - Returns: Array of fonts from this family
    ///
    /// Example:
    /// ```swift
    /// let ashevilleFonts = SystemFont.fonts(family: .ashevilleSans)
    /// for font in ashevilleFonts {
    ///     print(font.displayName)
    /// }
    /// ```
    static func fonts(family: FontFamily) -> [SystemFont] {
        return allCases.filter { $0.family == family }
    }

    /// Get all fonts of specific size
    ///
    /// - Parameter size: Size in points
    /// - Returns: Array of fonts of this size
    ///
    /// Example:
    /// ```swift
    /// let font14 = SystemFont.fonts(size: 14)
    /// // [.ashevilleSans14Bold, .ashevilleSans14Light, ...]
    /// ```
    static func fonts(size: Int) -> [SystemFont] {
        return allCases.filter { $0.pointSize == size }
    }

    /// Get all fonts of specific weight
    ///
    /// - Parameter weight: Font weight
    /// - Returns: Array of fonts with this weight
    ///
    /// Example:
    /// ```swift
    /// let boldFonts = SystemFont.fonts(weight: .bold)
    /// ```
    static func fonts(weight: FontWeight) -> [SystemFont] {
        return allCases.filter { $0.weight == weight }
    }

    /// Find font by parameters
    ///
    /// Returns first matching font or nil.
    ///
    /// - Parameters:
    ///   - family: Family (optional)
    ///   - size: Size (optional)
    ///   - weight: Weight (optional)
    ///   - style: Style (optional)
    /// - Returns: Found font or nil
    ///
    /// Example:
    /// ```swift
    /// // Find Roobert Bold of any size
    /// if let font = SystemFont.find(family: .roobert, weight: .bold) {
    ///     print(font.displayName)
    /// }
    ///
    /// // Find 14pt Light
    /// if let font = SystemFont.find(size: 14, weight: .light) {
    ///     _ = Font.loadSystem(font)
    /// }
    /// ```
    static func find(
        family: FontFamily? = nil,
        size: Int? = nil,
        weight: FontWeight? = nil,
        style: FontStyle? = nil
    ) -> SystemFont? {
        return allCases.first { font in
            if let family = family, font.family != family { return false }
            if let size = size, font.pointSize != size { return false }
            if let weight = weight, font.weight != weight { return false }
            if let style = style, font.style != style { return false }
            return true
        }
    }
}

// MARK: - Grouped Font Access

public extension SystemFont {
    /// All Asheville Sans fonts
    static var ashevilleSansFonts: [SystemFont] {
        return fonts(family: .ashevilleSans)
    }

    /// All Roobert fonts
    static var roobertFonts: [SystemFont] {
        return fonts(family: .roobert)
    }

    /// All bold fonts
    static var boldFonts: [SystemFont] {
        return fonts(weight: .bold)
    }

    /// All light fonts
    static var lightFonts: [SystemFont] {
        return fonts(weight: .light)
    }

    /// All medium weight fonts
    static var mediumFonts: [SystemFont] {
        return fonts(weight: .medium)
    }
}

// MARK: - Usage Examples

/*

 # SystemFont Usage Examples

 ## Basic Usage

 ```swift
 // Load system font
 let font = Font.loadSystem(.ashevilleSans14Bold)

 switch font {
 case .success(let f):
 f.setAsCurrent()
 Graphics.drawText("Hello", at: Point(x: 10, y: 10))
 case .failure(let error):
 print("Error: \(error)")
 }

 // Shorter version
 _ = Font.loadSystemAndSetCurrent(.roobert20Medium)
 Graphics.drawText("Title", at: Point(x: 10, y: 10))

 */
