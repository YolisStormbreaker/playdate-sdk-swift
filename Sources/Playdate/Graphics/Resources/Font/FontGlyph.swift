//
//  FontGlyph.swift
//  Playdate Graphics SDK
//
//  Created by Swift Playdate SDK
//  Copyright © 2024 Playdate SDK. All rights reserved.
//

import CPlaydate

/// Entity класс, представляющий глиф шрифта (LCDFontGlyph)
///
/// FontGlyph инкапсулирует C указатель на LCDFontGlyph и предоставляет
/// Swift-friendly интерфейс для работы с отдельным символом шрифта.
/// Содержит информацию о битмапе символа, его ширине и метриках.
public final class FontGlyph: GraphicsResource {
    // MARK: - Properties

    /// C указатель на LCDFontGlyph
    let cGlyph: OpaquePointer?

    /// Битмап глифа (может быть nil для пробельных символов)
    public let bitmap: Bitmap?

    /// Ширина продвижения символа в пикселях
    public let advance: Int

    /// Символ, представленный этим глифом
    public let character: UInt32

    /// Флаг валидности ресурса
    private var _isValid: Bool = true

    // MARK: - GraphicsResource Protocol

    public var isValid: Bool {
        return _isValid && cGlyph != nil
    }

    // MARK: - Initialization

    /// Инициализация с C указателем и данными глифа
    /// - Parameters:
    ///   - cGlyph: C указатель на LCDFontGlyph
    ///   - bitmap: Битмап глифа (может быть nil)
    ///   - advance: Ширина продвижения в пикселях
    ///   - character: Кодовая точка символа
    ///   - parentPage: Родительская страница шрифта
    init(
        cGlyph: OpaquePointer,
        bitmap: Bitmap?,
        advance: Int,
        character: UInt32,
        parentPage _: FontPage
    ) {
        self.cGlyph = cGlyph
        self.bitmap = bitmap
        self.advance = advance
        self.character = character
    }

    // MARK: - Deinitialization

    deinit {
        invalidate()
    }

    // MARK: - Public Methods

    /// Получает кернинг между этим глифом и следующим символом
    /// - Parameters:
    ///   - nextCharacter: Кодовая точка следующего символа
    /// - Returns: Значение кернинга в пикселях (может быть отрицательным)
    /// - Throws: GraphicsError, если операция не удалась
    public func getKerning(to nextCharacter: UInt32) throws -> Int {
        guard isValid else {
            throw GraphicsError.invalidResource("FontGlyph is invalid")
        }

        guard let graphics = GraphicsContext.shared.graphicsAPI else {
            throw GraphicsError.graphicsNotAvailable
        }

        let kerning = graphics.getGlyphKerning(cGlyph, character, nextCharacter)
        return Int(kerning)
    }

    /// Получает кернинг между этим глифом и следующим символом (Character)
    /// - Parameter nextCharacter: Swift Character
    /// - Returns: Значение кернинга в пикселях
    /// - Throws: GraphicsError, если операция не удалась
    public func getKerning(to nextCharacter: Character) throws -> Int {
        let unicodeScalars = nextCharacter.unicodeScalars
        guard let firstScalar = unicodeScalars.first else {
            throw GraphicsError.invalidParameter("Invalid character")
        }

        return try getKerning(to: firstScalar.value)
    }

    /// Вычисляет общую ширину этого символа включая кернинг с следующим
    /// - Parameter nextCharacter: Следующий символ
    /// - Returns: Общая ширина в пикселях
    /// - Throws: GraphicsError, если операция не удалась
    public func getTotalWidth(beforeNext nextCharacter: UInt32) throws -> Int {
        let kerning = try getKerning(to: nextCharacter)
        return advance + kerning
    }

    /// Вычисляет общую ширину этого символа включая кернинг с следующим (Character)
    /// - Parameter nextCharacter: Swift Character
    /// - Returns: Общая ширина в пикселях
    /// - Throws: GraphicsError, если операция не удалась
    public func getTotalWidth(beforeNext nextCharacter: Character) throws -> Int {
        let kerning = try getKerning(to: nextCharacter)
        return advance + kerning
    }

    /// Проверяет, имеет ли глиф видимое изображение
    /// - Returns: true, если у глифа есть битмап
    public var hasVisibleContent: Bool {
        return bitmap != nil
    }

    /// Получает размеры битмапа глифа
    /// - Returns: Размер битмапа или (0, 0) если битмапа нет
    /// - Throws: GraphicsError, если операция не удалась
    public func getBitmapSize() throws -> (width: Int, height: Int) {
        guard let bitmap = bitmap else {
            return (width: 0, height: 0)
        }

        return try (width: bitmap.getWidth(), height: bitmap.getHeight())
    }

    /// Получает метрики глифа
    /// - Returns: Структура с метриками глифа
    /// - Throws: GraphicsError, если операция не удалась
    public func getMetrics() throws -> GlyphMetrics {
        let bitmapSize = try getBitmapSize()

        return GlyphMetrics(
            character: character,
            advance: advance,
            bitmapWidth: bitmapSize.width,
            bitmapHeight: bitmapSize.height,
            hasVisibleContent: hasVisibleContent
        )
    }

    // MARK: - Internal Methods

    /// Инвалидирует ресурс
    func invalidate() {
        _isValid = false
        // Примечание: FontGlyph не владеет C ресурсом напрямую,
        // память управляется родительским Font/FontPage объектом
    }

    // MARK: - Helper Methods

    /// Возвращает символ как Swift Character (если возможно)
    /// - Returns: Character или nil, если не удается преобразовать
    public var swiftCharacter: Character? {
        guard let unicodeScalar = UnicodeScalar(character) else {
            return nil
        }
        return Character(unicodeScalar)
    }

    /// Форматирует число в шестнадцатеричную строку для embedded Swift
    /// - Parameter value: Число для форматирования
    /// - Returns: Шестнадцатеричная строка с префиксом U+
    private func formatHex(_ value: UInt32) -> String {
        let hexString = String(value, radix: 16).uppercased()
        let paddedHex = String(repeating: "0", count: max(0, 4 - hexString.count)) + hexString
        return "U+" + paddedHex
    }

    /// Возвращает информацию о глифе для отладки
    /// - Returns: Строковое представление глифа
    public var debugDescription: String {
        let charDesc = swiftCharacter.map { "'\($0)'" } ?? formatHex(character)
        return "FontGlyph(\(charDesc), advance: \(advance), hasContent: \(hasVisibleContent), valid: \(isValid))"
    }
}

// MARK: - Supporting Types

/// Структура с метриками глифа
public struct GlyphMetrics {
    /// Кодовая точка символа
    public let character: UInt32

    /// Ширина продвижения в пикселях
    public let advance: Int

    /// Ширина битмапа в пикселях
    public let bitmapWidth: Int

    /// Высота битмапа в пикселях
    public let bitmapHeight: Int

    /// Есть ли видимое содержимое
    public let hasVisibleContent: Bool

    /// Возвращает символ как Swift Character (если возможно)
    public var swiftCharacter: Character? {
        guard let unicodeScalar = UnicodeScalar(character) else {
            return nil
        }
        return Character(unicodeScalar)
    }
}

// MARK: - CustomStringConvertible

extension FontGlyph: CustomStringConvertible {
    public var description: String {
        return debugDescription
    }
}

// MARK: - Equatable

extension FontGlyph: Equatable {
    public static func == (lhs: FontGlyph, rhs: FontGlyph) -> Bool {
        return lhs.cGlyph == rhs.cGlyph && lhs.character == rhs.character
    }
}

// MARK: - Hashable

extension FontGlyph: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
        hasher.combine(character)
    }
}

// MARK: - GlyphMetrics Extensions

extension GlyphMetrics: CustomStringConvertible {
    /// Форматирует число в шестнадцатеричную строку для embedded Swift
    /// - Parameter value: Число для форматирования
    /// - Returns: Шестнадцатеричная строка с префиксом U+
    private func formatHex(_ value: UInt32) -> String {
        let hexString = String(value, radix: 16).uppercased()
        let paddedHex = String(repeating: "0", count: max(0, 4 - hexString.count)) + hexString
        return "U+" + paddedHex
    }

    public var description: String {
        let charDesc = swiftCharacter.map { "'\($0)'" } ?? formatHex(character)
        return "GlyphMetrics(\(charDesc), advance: \(advance), size: \(bitmapWidth)×\(bitmapHeight))"
    }
}

extension GlyphMetrics: Equatable {
    public static func == (lhs: GlyphMetrics, rhs: GlyphMetrics) -> Bool {
        return lhs.character == rhs.character &&
            lhs.advance == rhs.advance &&
            lhs.bitmapWidth == rhs.bitmapWidth &&
            lhs.bitmapHeight == rhs.bitmapHeight &&
            lhs.hasVisibleContent == rhs.hasVisibleContent
    }
}
