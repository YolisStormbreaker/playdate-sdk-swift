//
// Font.swift
// Playdate Graphics SDK
//
// Entity класс для работы со шрифтами LCDFont
// Инкапсулирует C указатель и управляет жизненным циклом ресурса
//
import CPlaydate

/// Entity класс для работы со шрифтами Playdate
/// Инкапсулирует LCDFont* и обеспечивает Swift-friendly интерфейс
public final class Font {
	
	// MARK: - Private Properties
	
	/// C указатель на LCDFont (может быть nil если ресурс освобожден)
	private var _fontPtr: OpaquePointer?
	
	/// Флаг, указывающий, владеет ли этот объект C ресурсом
	/// Если true - освободит память в deinit, если false - не будет
	private let ownsResource: Bool
	
	/// Кэшированная высота шрифта для оптимизации
	private var _cachedHeight: UInt8?
		
	// MARK: - Public Properties
	
	/// Проверка, валиден ли шрифт (не освобожден ли C ресурс)
	public var isValid: Bool {
		return _fontPtr != nil
	}
	
	/// Высота шрифта в пикселях
	/// Кэширует значение для оптимизации повторных вызовов
	public var height: UInt8 {
		if let cached = _cachedHeight {
			return cached
		}
		
		guard let fontPtr = _fontPtr else { 
			return 0 
		}
		
		guard let graphicsAPI = GraphicsContext.shared.graphicsAPI else {
			return 0
		}
		
		// Вызов C API для получения высоты шрифта
		let height = graphicsAPI.getFontHeight(fontPtr)
		_cachedHeight = height
		return height
	}
	
	// MARK: - Initialization
	
	/// Внутренний инициализатор с C указателем
	/// - Parameters:
	///   - fontPtr: C указатель на LCDFont
	///   - ownsResource: Должен ли этот объект освобождать C ресурс при уничтожении
	internal init(fontPtr: OpaquePointer, ownsResource: Bool = true) {
		self._fontPtr = fontPtr
		self.ownsResource = ownsResource
	}
	
	/// Создание шрифта из данных LCDFontData (для внутреннего использования)
	/// - Parameters:
	///   - fontData: Указатель на LCDFontData  
	///   - wide: Флаг широких символов
	internal init?(fontData: OpaquePointer, wide: Bool) {
		guard let graphicsAPI = GraphicsContext.shared.graphicsAPI else {
			return
		}
		let fontPtr = graphicsAPI.makeFontFromData(fontData, wide ? 1 : 0)
		guard fontPtr != nil else {
			return nil
		}
		
		self._fontPtr = fontPtr
		self.ownsResource = true
	}
	
	// MARK: - Deinitialization
	
	deinit {
		// Освобождаем C ресурс только если мы им владеем
		// Примечание: В текущем C API нет функции freeLCDFont,
		// предполагаем, что шрифты управляются системой Playdate
		// Если в будущем появится freeFont, раскомментировать:
		
		/*
		if ownsResource, let fontPtr = _fontPtr {
			GraphicsContext.shared.graphicsAPI.freeFont(fontPtr)
		}
		*/
		
		_fontPtr = nil
	}
	
	// MARK: - Text Measurement Methods
	
	/// Вычисляет ширину текста в пикселях при рендеринге этим шрифтом
	/// - Parameters:
	///   - text: Текст для измерения  
	///   - encoding: Кодировка текста (по умолчанию UTF-8)
	///   - tracking: Дополнительное расстояние между символами
	/// - Returns: Ширина в пикселях или 0 если шрифт невалиден
	public func getTextWidth(_ text: String, 
							encoding: StringEncoding = .utf8,
							tracking: Int32 = 0) -> Int32 {
		guard let fontPtr = _fontPtr else { 
			return 0 
		}
		
		// Используем новую утилитарную функцию
		return text.withCBytes(encoding: encoding) { pointer, count in
			guard let pointer = pointer else { return 0 }
			guard let graphicsAPI = GraphicsContext.shared.graphicsAPI else {
				return 0
			}
			
			return graphicsAPI.getTextWidth(
				fontPtr,
				pointer,
				count,
				encoding.cValue,
				tracking
			)
		}
	}
	
	/// Вычисляет высоту текста для заданной максимальной ширины с переносом
	public func getTextHeight(_ text: String,
							 maxWidth: Int32,
							 encoding: StringEncoding = .utf8,
							 wrapping: TextWrappingMode = .word,
							 tracking: Int32 = 0,
							 leading: Int32 = 0) -> Int32 {
		guard let fontPtr = _fontPtr else { 
			return 0 
		}
		
		guard let graphicsAPI = GraphicsContext.shared.graphicsAPI else {
			return 0
		}
		
		// Используем новую утилитарную функцию
		return text.withCBytes(encoding: encoding) { pointer, count in
			guard let pointer = pointer else { return 0 }
			
			return graphicsAPI.getTextHeightForMaxWidth(
				fontPtr,
				pointer,
				count,
				maxWidth,
				encoding.cValue,
				wrapping.cValue,
				tracking,
				leading
			)
		}
	}
	
	// MARK: - Font Context Methods
	
	/// Устанавливает этот шрифт как текущий для операций рисования
	/// После вызова все операции drawText будут использовать этот шрифт
	public func setAsCurrent() {
		guard let fontPtr = _fontPtr else { 
			return 
		}
		
		guard let graphicsAPI = GraphicsContext.shared.graphicsAPI else {
			return
		}
		
		graphicsAPI.setFont(fontPtr)
	}
	
	// MARK: - Advanced Font Access
	
	/// Получает страницу шрифта для заданного символа
	/// Используется для низкоуровневого доступа к глифам
	/// - Parameter character: Unicode символ
	/// - Returns: FontPage или nil если символ не найден
	public func getFontPage(for character: UnicodeScalar) -> FontPage? {
		guard let fontPtr = _fontPtr else { 
			return nil 
		}
		
		guard let graphicsAPI = GraphicsContext.shared.graphicsAPI else {
			return nil
		}
		
		let pagePtr = graphicsAPI.getFontPage(fontPtr, character.value)
		guard pagePtr != nil else {
			return nil
		}
		
		return FontPage(pagePtr: pagePtr!, parentFont: self)
	}
	
	// MARK: - Internal Access
	
	/// Внутренний доступ к C указателю для использования в других частях SDK
	/// Не должен использоваться внешними клиентами
	internal var cFontPtr: OpaquePointer? {
		return _fontPtr
	}
	
	/// Принудительно инвалидирует шрифт (для использования ResourceManager)
	internal func invalidate() {
		_fontPtr = nil
		_cachedHeight = nil
	}
}

// MARK: - GraphicsResource Protocol Conformance

extension Font: GraphicsResource {
	
	/// Тип C ресурса
	public typealias CResourceType = OpaquePointer
	
	/// Освобождение ресурса (вызывается ResourceManager)
	public func releaseResource() {
		// В текущем API нет явной функции освобождения шрифтов
		// Предполагается, что они управляются системой
		invalidate()
	}
	
	/// Проверка валидности ресурса
	public var isResourceValid: Bool {
		return isValid
	}
}

// MARK: - Equatable Conformance

extension Font: Equatable {
	
	/// Сравнение шрифтов по C указателю
	public static func == (lhs: Font, rhs: Font) -> Bool {
		return lhs._fontPtr == rhs._fontPtr
	}
}

// MARK: - CustomStringConvertible for Debugging

extension Font: CustomStringConvertible {
	
	public var description: String {
		if isValid {
			return "Font(height: \(height)px, valid: true)"
		} else {
			return "Font(invalid)"
		}
	}
}

// MARK: - String Extensions for Data Conversion

private extension String {
	
	/// Преобразует строку в массив байт для заданной кодировки
	/// Fallback реализация для отсутствия Foundation
	func data(using encoding: StringEncoding) -> [UInt8]? {
		switch encoding {
		case .ascii:
			return Array(self.utf8.prefix(while: { $0 < 128 }))
		case .utf8:
			return Array(self.utf8)
		case .utf16LE:
			// Простая реализация UTF-16LE без Foundation
			var result: [UInt8] = []
			for scalar in self.unicodeScalars {
				let value = scalar.value
				if value <= 0xFFFF {
					// BMP символ - один 16-битный код
					result.append(UInt8(value & 0xFF))
					result.append(UInt8((value >> 8) & 0xFF))
				} else {
					// Суррогатная пара для символов вне BMP
					let adjusted = value - 0x10000
					let high = 0xD800 + (adjusted >> 10)
					let low = 0xDC00 + (adjusted & 0x3FF)
					
					result.append(UInt8(high & 0xFF))
					result.append(UInt8((high >> 8) & 0xFF))
					result.append(UInt8(low & 0xFF)) 
					result.append(UInt8((low >> 8) & 0xFF))
				}
			}
			return result
		}
	}
}
