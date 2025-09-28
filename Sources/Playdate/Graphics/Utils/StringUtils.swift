//
// StringUtils.swift  
// Playdate Graphics SDK
//
// Утилиты для работы со строками без Foundation
// Преобразование строк в байтовые массивы для различных кодировок
//

/// Extension для String с поддержкой кодировок Playdate SDK
extension String {
	
	/// Преобразует строку в массив байт для заданной кодировки
	/// - Parameter encoding: Кодировка для преобразования
	/// - Returns: Массив байт или пустой массив в случае ошибки
	public func toBytes(encoding: StringEncoding) -> [UInt8] {
		switch encoding {
		case .ascii:
			return toASCIIBytes()
		case .utf8:
			return toUTF8Bytes()
		case .utf16LE:
			return toUTF16LEBytes()
		}
	}
	
	/// Преобразует строку в ASCII байты (только символы < 128)
	/// - Returns: Массив ASCII байт
	public func toASCIIBytes() -> [UInt8] {
		return Array(self.utf8.filter { $0 < 128 })
	}
	
	/// Преобразует строку в UTF-8 байты
	/// - Returns: Массив UTF-8 байт
	public func toUTF8Bytes() -> [UInt8] {
		return Array(self.utf8)
	}
	
	/// Преобразует строку в UTF-16 Little Endian байты
	/// Поддерживает полный Unicode включая суррогатные пары
	/// - Returns: Массив UTF-16LE байт
	public func toUTF16LEBytes() -> [UInt8] {
		var result: [UInt8] = []
		
		for scalar in self.unicodeScalars {
			let value = scalar.value
			
			if value <= 0xFFFF {
				// BMP символ (Basic Multilingual Plane) - один 16-битный код
				result.append(UInt8(value & 0xFF))        // младший байт первым (Little Endian)
				result.append(UInt8((value >> 8) & 0xFF)) // старший байт вторым
			} else {
				// Символ вне BMP - нужна суррогатная пара
				let adjusted = value - 0x10000
				let highSurrogate = 0xD800 + (adjusted >> 10)
				let lowSurrogate = 0xDC00 + (adjusted & 0x3FF)
				
				// Высокий суррогат (Little Endian)
				result.append(UInt8(highSurrogate & 0xFF))
				result.append(UInt8((highSurrogate >> 8) & 0xFF))
				
				// Низкий суррогат (Little Endian)
				result.append(UInt8(lowSurrogate & 0xFF))
				result.append(UInt8((lowSurrogate >> 8) & 0xFF))
			}
		}
		
		return result
	}
	
	/// Вычисляет количество байт, которое займет строка в заданной кодировке
	/// Полезно для предварительного выделения памяти
	/// - Parameter encoding: Кодировка для вычисления
	/// - Returns: Количество байт
	public func byteCount(for encoding: StringEncoding) -> Int {
		switch encoding {
		case .ascii:
			return self.utf8.filter { $0 < 128 }.count
		case .utf8:
			return self.utf8.count
		case .utf16LE:
			var count = 0
			for scalar in self.unicodeScalars {
				if scalar.value <= 0xFFFF {
					count += 2 // BMP символ = 2 байта
				} else {
					count += 4 // Суррогатная пара = 4 байта
				}
			}
			return count
		}
	}
}

// MARK: - Дополнительные утилиты для C API интеграции

extension String {
	
	/// Выполняет операцию с байтами строки в заданной кодировке
	/// Оптимизированная версия для прямой передачи в C API
	/// - Parameters:
	///   - encoding: Кодировка строки
	///   - body: Замыкание, которое получает указатель на байты и их количество
	/// - Returns: Результат выполнения замыкания
	public func withCBytes<T>(encoding: StringEncoding, 
							 _ body: (UnsafeRawPointer?, Int) -> T) -> T {
		let bytes = toBytes(encoding: encoding)
		return bytes.withUnsafeBufferPointer { buffer in
			return body(buffer.baseAddress, buffer.count)
		}
	}
	
	/// Создает null-terminated C строку для ASCII/UTF-8 кодировок
	/// - Parameter encoding: Кодировка (должна быть .ascii или .utf8)
	/// - Returns: Массив байт с завершающим нулем
	public func toCString(encoding: StringEncoding = .utf8) -> [UInt8] {
		guard encoding == .ascii || encoding == .utf8 else {
			// UTF-16LE не подходит для C строк
			return []
		}
		
		var bytes = toBytes(encoding: encoding)
		bytes.append(0) // null terminator
		return bytes
	}
}

// MARK: - Validation утилиты

extension String {
	
	/// Проверяет, содержит ли строка только ASCII символы
	public var isASCII: Bool {
		return self.utf8.allSatisfy { $0 < 128 }
	}
	
	/// Проверяет, может ли строка быть представлена в заданной кодировке без потерь
	/// - Parameter encoding: Кодировка для проверки
	/// - Returns: true если кодировка поддерживает все символы строки
	public func canBeEncoded(in encoding: StringEncoding) -> Bool {
		switch encoding {
		case .ascii:
			return isASCII
		case .utf8, .utf16LE:
			return true // UTF-8 и UTF-16 поддерживают весь Unicode
		}
	}
}
