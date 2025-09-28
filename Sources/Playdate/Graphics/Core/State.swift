//
// GraphicsState.swift
// Playdate Graphics SDK
//
// Реализация State Pattern для управления состояниями рисования
// Инкапсулирует все параметры графического контекста
//

// MARK: - Graphics State Protocol
/// Базовый протокол для состояний графики
public protocol GraphicsStateProtocol {
	/// Применить состояние к текущему графическому контексту
	func apply()
	
	/// Валидировать параметры состояния
	func validate() -> Bool
	
	/// Создать копию состояния
	func copy() -> GraphicsStateProtocol
}

// MARK: - Drawing State
/// Основное состояние рисования, содержащее все параметры графического контекста
public struct DrawingState: GraphicsStateProtocol {
	
	// MARK: - State Properties
	
	/// Режим рисования битмапов
	public var drawMode: BitmapDrawMode
	
	/// Смещение для всех операций рисования
	public var drawOffset: Point
	
	/// Прямоугольник отсечения (nil = без отсечения)
	public var clipRect: Rect?
	
	/// Цвет фона
	public var backgroundColor: SolidColor
	
	/// Стиль окончаний линий
	public var lineCapStyle: LineCapStyle
	
	/// Текущий шрифт (nil = системный шрифт)
	public var currentFont: OpaquePointer? // LCDFont*
	
	/// Межсимвольный интервал для текста
	public var textTracking: Int32
	
	/// Межстрочный интервал для текста  
	public var textLeading: Int32
	
	/// Stencil битмап для маскирования (nil = без stencil)
	public var stencil: OpaquePointer? // LCDBitmap*
	
	/// Флаг тайлинга для stencil
	public var stencilTiled: Bool
	
	// MARK: - Initialization
	
	/// Инициализация с параметрами по умолчанию
	public init() {
		self.drawMode = .copy
		self.drawOffset = Point.zero
		self.clipRect = nil
		self.backgroundColor = .white
		self.lineCapStyle = .butt
		self.currentFont = nil
		self.textTracking = 0
		self.textLeading = 0
		self.stencil = nil
		self.stencilTiled = false
	}
	
	/// Полная инициализация всех параметров
	public init(drawMode: BitmapDrawMode = .copy,
				drawOffset: Point = Point.zero,
				clipRect: Rect? = nil,
				backgroundColor: SolidColor = .white,
				lineCapStyle: LineCapStyle = .butt,
				currentFont: OpaquePointer? = nil,
				textTracking: Int32 = 0,
				textLeading: Int32 = 0,
				stencil: OpaquePointer? = nil,
				stencilTiled: Bool = false) {
		
		self.drawMode = drawMode
		self.drawOffset = drawOffset
		self.clipRect = clipRect
		self.backgroundColor = backgroundColor
		self.lineCapStyle = lineCapStyle
		self.currentFont = currentFont
		self.textTracking = textTracking
		self.textLeading = textLeading
		self.stencil = stencil
		self.stencilTiled = stencilTiled
	}
	
	// MARK: - GraphicsStateProtocol Implementation
	
	/// Применяет состояние к C API через указатели на функции
	/// Предполагается, что gfx - это указатель на playdate_graphics структуру
	public func apply() {
		// Получение указателя на C API будет реализовано в GraphicsContext
		guard let graphicsAPI = GraphicsContext.shared.graphicsAPI else {
			return
		}
		
		// Применение режима рисования
		_ = graphicsAPI.setDrawMode(drawMode.cValue)
		
		// Применение смещения рисования  
		graphicsAPI.setDrawOffset(drawOffset.x, drawOffset.y)
		
		// Применение отсечения
		if let rect = clipRect {
			graphicsAPI.setClipRect(rect.x, rect.y, rect.width, rect.height)
		} else {
			graphicsAPI.clearClipRect()
		}
		
		// Применение цвета фона
		graphicsAPI.setBackgroundColor(backgroundColor.cValue)
		
		// Применение стиля линий
		graphicsAPI.setLineCapStyle(lineCapStyle.cValue)
		
		// Применение шрифта
		if let font = currentFont {
			graphicsAPI.setFont(font)
		}
		
		// Применение параметров текста
		graphicsAPI.setTextTracking(textTracking)
		graphicsAPI.setTextLeading(textLeading)
		
		// Применение stencil
		if let stencilBitmap = stencil {
			graphicsAPI.setStencilImage(stencilBitmap, stencilTiled ? 1 : 0)
		}
	}
	
	/// Валидация параметров состояния
	public func validate() -> Bool {
		// Проверка смещения (не должно быть слишком большим)
		let maxOffset: Int32 = 10000
		guard abs(drawOffset.x) < maxOffset && abs(drawOffset.y) < maxOffset else {
			return false
		}
		
		// Проверка clipRect (должен иметь положительные размеры если установлен)
		if let rect = clipRect {
			guard rect.width > 0 && rect.height > 0 else {
				return false
			}
			
			// Проверка что clipRect не выходит за разумные границы
			guard rect.left >= -maxOffset && rect.top >= -maxOffset &&
				  rect.right <= Screen.columns + maxOffset && 
				  rect.bottom <= Screen.rows + maxOffset else {
				return false
			}
		}
		
		// Проверка параметров текста (разумные диапазоны)
		guard textTracking >= -100 && textTracking <= 100 else {
			return false
		}
		
		guard textLeading >= -50 && textLeading <= 200 else {
			return false
		}
		
		return true
	}
	
	/// Создание копии состояния
	public func copy() -> GraphicsStateProtocol {
		return DrawingState(drawMode: self.drawMode,
						   drawOffset: self.drawOffset,
						   clipRect: self.clipRect,
						   backgroundColor: self.backgroundColor,
						   lineCapStyle: self.lineCapStyle,
						   currentFont: self.currentFont,
						   textTracking: self.textTracking,
						   textLeading: self.textLeading,
						   stencil: self.stencil,
						   stencilTiled: self.stencilTiled)
	}
}

// MARK: - State Stack
/// Стек состояний для push/pop операций контекста
public struct GraphicsStateStack {
	private var states: [GraphicsStateProtocol]
	private var currentState: GraphicsStateProtocol
	
	/// Максимальная глубина стека для предотвращения переполнения
	private static let maxStackDepth: Int = 32
	
	// MARK: - Initialization
	
	/// Инициализация с состоянием по умолчанию
	public init() {
		self.currentState = DrawingState()
		self.states = []
	}
	
	/// Инициализация с начальным состоянием
	public init(initialState: GraphicsStateProtocol) {
		self.currentState = initialState
		self.states = []
	}
	
	// MARK: - Stack Operations
	
	/// Получить текущее состояние
	public var current: GraphicsStateProtocol {
		return currentState
	}
	
	/// Глубина стека
	public var depth: Int {
		return states.count
	}
	
	/// Сохранить текущее состояние в стек и создать новое
	public mutating func push() -> Bool {
		// Проверка переполнения стека
		guard states.count < Self.maxStackDepth else {
			return false
		}
		
		// Валидация текущего состояния перед сохранением
		guard currentState.validate() else {
			return false
		}
		
		states.append(currentState.copy())
		return true
	}
	
	/// Восстановить состояние из стека
	public mutating func pop() -> Bool {
		guard !states.isEmpty else {
			return false
		}
		
		currentState = states.removeLast()
		
		// Применить восстановленное состояние
		currentState.apply()
		
		return true
	}
	
	/// Обновить текущее состояние
	public mutating func setCurrent(_ newState: GraphicsStateProtocol) -> Bool {
		guard newState.validate() else {
			return false
		}
		
		currentState = newState
		currentState.apply()
		return true
	}
	
	/// Очистить весь стек (оставить только текущее состояние)
	public mutating func clear() {
		states.removeAll()
	}
	
	/// Применить текущее состояние к графическому контексту
	public func applyCurrent() {
		currentState.apply()
	}
}

// MARK: - Specialized States
/// Специализированное состояние для операций с текстом
public struct TextDrawingState: GraphicsStateProtocol {
	public let baseState: DrawingState
	public let encoding: StringEncoding
	public let wrappingMode: TextWrappingMode
	public let alignment: TextAlignment
	
	public init(baseState: DrawingState, 
				encoding: StringEncoding = .utf8,
				wrappingMode: TextWrappingMode = .word,
				alignment: TextAlignment = .left) {
		self.baseState = baseState
		self.encoding = encoding
		self.wrappingMode = wrappingMode  
		self.alignment = alignment
	}
	
	public func apply() {
		baseState.apply()
		// Дополнительные параметры текста применяются при вызове конкретных функций рисования
	}
	
	public func validate() -> Bool {
		return baseState.validate()
	}
	
	public func copy() -> GraphicsStateProtocol {
		return TextDrawingState(baseState: baseState.copy() as! DrawingState,
							   encoding: encoding,
							   wrappingMode: wrappingMode,
							   alignment: alignment)
	}
}

/// Специализированное состояние для операций с битмапами
public struct BitmapDrawingState: GraphicsStateProtocol {
	public let baseState: DrawingState
	public let flip: BitmapFlip
	public let scale: (x: Float, y: Float)
	public let rotation: Float
	
	public init(baseState: DrawingState,
				flip: BitmapFlip = .none,
				scale: (x: Float, y: Float) = (1.0, 1.0),
				rotation: Float = 0.0) {
		self.baseState = baseState
		self.flip = flip
		self.scale = scale
		self.rotation = rotation
	}
	
	public func apply() {
		baseState.apply()
		// Параметры битмапа применяются при вызове конкретных функций рисования
	}
	
	public func validate() -> Bool {
		guard baseState.validate() else { return false }
		
		// Валидация масштаба (не должен быть нулевым или слишком большим)
		guard scale.x > 0.001 && scale.x < 100.0 && 
			  scale.y > 0.001 && scale.y < 100.0 else {
			return false
		}
		
		return true
	}
	
	public func copy() -> GraphicsStateProtocol {
		return BitmapDrawingState(baseState: baseState.copy() as! DrawingState,
								 flip: flip,
								 scale: scale,
								 rotation: rotation)
	}
}

// MARK: - State Factory
/// Фабрика для создания предустановленных состояний
public struct GraphicsStateFactory {
	
	/// Состояние по умолчанию для рисования
	public static func defaultDrawingState() -> DrawingState {
		return DrawingState()
	}
	
	/// Состояние для прозрачного рисования
	public static func transparentState(transparent: SolidColor) -> DrawingState {
		let drawMode: BitmapDrawMode = transparent == .white ? .whiteTransparent : .blackTransparent
		return DrawingState(drawMode: drawMode)
	}
	
	/// Состояние для XOR рисования
	public static func xorState() -> DrawingState {
		return DrawingState(drawMode: .xor)
	}
	
	/// Состояние для инвертированного рисования
	public static func invertedState() -> DrawingState {
		return DrawingState(drawMode: .inverted)
	}
	
	/// Состояние с отсечением по прямоугольнику
	public static func clippedState(clipRect: Rect) -> DrawingState {
		return DrawingState(clipRect: clipRect)
	}
}
