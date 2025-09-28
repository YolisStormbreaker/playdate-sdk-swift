//
// GraphicsContext.swift
// Playdate Graphics SDK
//
// [SINGLETON] Управление глобальным состоянием графического контекста
// Обеспечивает доступ к C API и управление стеком состояний
//
import CPlaydate

/// Централизованный менеджер графического контекста Playdate
/// Реализует паттерн Singleton для управления глобальным состоянием рисования
/// @unchecked Sendable: Playdate SDK работает в single-threaded среде,
/// поэтому мы гарантируем thread safety на уровне архитектуры приложения
public final class GraphicsContext: @unchecked Sendable {
	
	// MARK: - Singleton
	/// Единственный экземпляр GraphicsContext
	public static let shared = GraphicsContext()
	
	/// Приватный инициализатор для предотвращения создания дополнительных экземпляров
	private init() {
		// Инициализация базового состояния
		_drawMode = .copy
		_drawOffset = Point.zero
		_lineCapStyle = .butt
		_backgroundColor = .white
		_clipRect = nil
		_screenClipRect = nil
		_textTracking = 0
		_textLeading = 0
		_currentFont = nil
		_currentStencil = nil
		_isStencilTiled = false
		_contextStack = []
		_currentTarget = nil
		
		// Инициализация с C API состояниями по умолчанию
		initializeDefaultStates()
	}
	
	// MARK: - Core State Properties
	/// Текущий режим рисования битмапов
	private var _drawMode: BitmapDrawMode
	
	/// Смещение для всех операций рисования
	private var _drawOffset: Point
	
	/// Стиль окончаний линий
	private var _lineCapStyle: LineCapStyle
	
	/// Цвет фона
	private var _backgroundColor: SolidColor
	
	/// Текущая область отсечения (nil = нет отсечения)
	private var _clipRect: Rect?
	
	/// Область отсечения экрана
	private var _screenClipRect: Rect?
	
	/// Текущее расстояние между символами текста
	private var _textTracking: Int32
	
	/// Дополнительное расстояние между строками текста
	private var _textLeading: Int32
	
	/// Текущий шрифт (nil = системный шрифт)
	private var _currentFont: UnsafeMutableRawPointer?  // LCDFont*
	
	/// Текущий stencil (трафарет) для рисования
	private var _currentStencil: UnsafeMutableRawPointer?  // LCDBitmap*
	
	/// Флаг - является ли stencil тайлированным
	private var _isStencilTiled: Bool
	
	// MARK: - Context Stack
	/// Структура для сохранения состояния контекста
	private struct ContextState {
		let drawMode: BitmapDrawMode
		let drawOffset: Point
		let lineCapStyle: LineCapStyle
		let backgroundColor: SolidColor
		let clipRect: Rect?
		let textTracking: Int32
		let textLeading: Int32
		let font: UnsafeMutableRawPointer?
		let stencil: UnsafeMutableRawPointer?
		let isStencilTiled: Bool
		let target: UnsafeMutableRawPointer?
	}
	
	/// Стек сохранённых состояний контекста
	private var _contextStack: [ContextState]
	
	/// Текущий target bitmap для рисования (nil = экран)
	private var _currentTarget: UnsafeMutableRawPointer?  // LCDBitmap*
	
	// MARK: - Initialization Helpers
	/// Инициализирует состояния C API значениями по умолчанию
	private func initializeDefaultStates() {
		// Пока оставим пустым - будем заполнять в следующих частях
		// когда будем добавлять конкретные методы для работы с C API
	}
	
	// MARK: - Public Read-Only Access to State
	
	public var graphicsAPI: playdate_graphics? {
		guard isInitialized else { return nil }
		return _graphicsAPI
	}
	
	private var isInitialized: Bool = false
	private var _graphicsAPI: playdate_graphics { playdateAPI.graphics.unsafelyUnwrapped.pointee }
	
	/// Текущий режим рисования (read-only)
	public var drawMode: BitmapDrawMode {
		return _drawMode
	}
	
	/// Текущее смещение рисования (read-only)
	public var drawOffset: Point {
		return _drawOffset
	}
	
	/// Текущий стиль окончаний линий (read-only)
	public var lineCapStyle: LineCapStyle {
		return _lineCapStyle
	}
	
	/// Текущий цвет фона (read-only)
	public var backgroundColor: SolidColor {
		return _backgroundColor
	}
	
	/// Текущая область отсечения (read-only)
	public var clipRect: Rect? {
		return _clipRect
	}
	
	/// Текущий tracking текста (read-only)
	public var textTracking: Int32 {
		return _textTracking
	}
	
	/// Текущий leading текста (read-only)
	public var textLeading: Int32 {
		return _textLeading
	}
	
	/// Есть ли активный stencil (read-only)
	public var hasStencil: Bool {
		return _currentStencil != nil
	}
	
	/// Количество элементов в стеке контекстов (read-only)
	public var contextStackDepth: Int {
		return _contextStack.count
	}
	
	/// Рисуем ли мы в bitmap или на экран (read-only)
	public var isDrawingToScreen: Bool {
		return _currentTarget == nil
	}
}
