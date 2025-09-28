//
//  FontPage.swift
//  Playdate Graphics SDK
//

import CPlaydate

/// Entity класс, представляющий страницу шрифта (LCDFontPage)
///
/// FontPage инкапсулирует C указатель на LCDFontPage и предоставляет
/// Swift-friendly интерфейс для работы со страницей шрифта.
/// Страница шрифта содержит глифы для определенного диапазона символов.
public final class FontPage {
    // MARK: - Properties

    /// C указатель на LCDFontPage
    let cFontPage: OpaquePointer?

    /// Кодовая точка символа, для которого была создана эта страница
    public let codePoint: UInt32

    /// Флаг валидности ресурса
    private var _isValid: Bool = true

    // MARK: - GraphicsResource Protocol

    public var isValid: Bool {
        return _isValid && cFontPage != nil
    }

    // MARK: - Initialization

    /// Инициализация с C указателем
    /// - Parameters:
    ///   - cFontPage: C указатель на LCDFontPage
    ///   - codePoint: Кодовая точка символа
    init(cFontPage: OpaquePointer, codePoint: UInt32) {
        self.cFontPage = cFontPage
        self.codePoint = codePoint
    }

    // MARK: - Deinitialization

    deinit {
        invalidate()
    }

    // MARK: - Public Methods

    /// Получает глиф для указанного символа на этой странице
    /// - Parameter character: Символ для получения глифа
    /// - Returns: FontGlyph или nil, если глиф не найден
    /// - Throws: GraphicsError, если операция не удалась
    public func getGlyph(for character: UInt32) throws -> FontGlyph? {
        guard isValid else {
            throw GraphicsError.invalidResource("FontPage is invalid")
        }

        guard let graphics = GraphicsContext.shared.graphicsAPI else {
            throw GraphicsError.graphicsNotAvailable
        }

        var cBitmap: OpaquePointer?
        var advance: Int32 = 0

        let cGlyph = graphics.pointee.getPageGlyph(cFontPage, character, &cBitmap, &advance)

        guard let validGlyph = cGlyph else {
            return nil
        }

        // Создаем Bitmap для глифа, если он существует
        var bitmap: Bitmap?
        if let validBitmap = cBitmap {
            bitmap = Bitmap(cBitmap: validBitmap, ownsResource: false)
        }

        return FontGlyph(
            cGlyph: validGlyph,
            bitmap: bitmap,
            advance: Int(advance),
            character: character,
            parentPage: self
        )
    }

    /// Получает глиф для указанного символа (Character)
    /// - Parameter character: Swift Character
    /// - Returns: FontGlyph или nil, если глиф не найден
    /// - Throws: GraphicsError, если операция не удалась
    public func getGlyph(for character: Character) throws -> FontGlyph? {
        let unicodeScalars = character.unicodeScalars
        guard let firstScalar = unicodeScalars.first else {
            throw GraphicsError.invalidParameter("Invalid character")
        }

        return try getGlyph(for: firstScalar.value)
    }

    /// Получает глиф для указанного символа из строки
    /// - Parameters:
    ///   - string: Строка
    ///   - index: Индекс символа в строке
    /// - Returns: FontGlyph или nil, если глиф не найден
    /// - Throws: GraphicsError, если операция не удалась
    public func getGlyph(from string: String, at index: String.Index) throws -> FontGlyph? {
        guard string.indices.contains(index) else {
            throw GraphicsError.invalidParameter("String index out of bounds")
        }

        let character = string[index]
        return try getGlyph(for: character)
    }

    /// Проверяет, содержит ли эта страница глиф для указанного символа
    /// - Parameter character: Символ для проверки
    /// - Returns: true, если глиф существует
    public func hasGlyph(for character: UInt32) -> Bool {
        do {
            return try getGlyph(for: character) != nil
        } catch {
            return false
        }
    }

    /// Проверяет, содержит ли эта страница глиф для указанного символа (Character)
    /// - Parameter character: Swift Character
    /// - Returns: true, если глиф существует
    public func hasGlyph(for character: Character) -> Bool {
        do {
            return try getGlyph(for: character) != nil
        } catch {
            return false
        }
    }

    // MARK: - Internal Methods

    /// Инвалидирует ресурс
    func invalidate() {
        _isValid = false
        // Примечание: FontPage не владеет C ресурсом напрямую,
        // память управляется родительским Font объектом
    }

    // MARK: - Helper Methods

    /// Получает информацию о диапазоне символов на этой странице
    /// - Returns: Информация о странице в виде строки
    public var debugDescription: String {
        return "FontPage(codePoint: U+\(String(format: "%04X", codePoint)), valid: \(isValid))"
    }
}

// MARK: - CustomStringConvertible

extension FontPage: CustomStringConvertible {
    public var description: String {
        return debugDescription
    }
}

// MARK: - Equatable

extension FontPage: Equatable {
    public static func == (lhs: FontPage, rhs: FontPage) -> Bool {
        return lhs.cFontPage == rhs.cFontPage && lhs.codePoint == rhs.codePoint
    }
}

// MARK: - Hashable

extension FontPage: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
        hasher.combine(codePoint)
    }
}
