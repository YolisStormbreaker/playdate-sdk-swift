//
// StringUtils.swift
// Playdate Graphics SDK
//
// Утилиты для работы со строками без Foundation
// Преобразование строк в байтовые массивы для различных кодировок
// Оптимизировано для Embedded Swift на Playdate (без grapheme breaking)
//

// MARK: - UTF-8 Decoder (Manual Implementation)

/// Manual UTF-8 decoder for converting to UTF-16LE without Foundation
///
/// Decodes UTF-8 byte sequences into Unicode code points
/// without using Swift's String.unicodeScalars (which causes grapheme breaking)
enum UTF8Decoder {
    /// Decode UTF-8 bytes to Unicode code points
    ///
    /// - Parameter bytes: UTF-8 encoded bytes
    /// - Returns: Array of Unicode code points (UInt32)
    static func decode(_ bytes: [UInt8]) -> [UInt32] {
        var codePoints: [UInt32] = []
        var index = 0

        while index < bytes.count {
            let byte = bytes[index]

            if byte & 0b1000_0000 == 0 {
                // 1-byte sequence: 0xxxxxxx (ASCII, 0-127)
                codePoints.append(UInt32(byte))
                index += 1

            } else if byte & 0b1110_0000 == 0b1100_0000 {
                // 2-byte sequence: 110xxxxx 10xxxxxx (128-2047)
                guard index + 1 < bytes.count else { break }

                let byte1 = bytes[index]
                let byte2 = bytes[index + 1]

                let codePoint = (UInt32(byte1 & 0b0001_1111) << 6) |
                    UInt32(byte2 & 0b0011_1111)

                codePoints.append(codePoint)
                index += 2

            } else if byte & 0b1111_0000 == 0b1110_0000 {
                // 3-byte sequence: 1110xxxx 10xxxxxx 10xxxxxx (2048-65535)
                guard index + 2 < bytes.count else { break }

                let byte1 = bytes[index]
                let byte2 = bytes[index + 1]
                let byte3 = bytes[index + 2]

                let codePoint = (UInt32(byte1 & 0b0000_1111) << 12) |
                    (UInt32(byte2 & 0b0011_1111) << 6) |
                    UInt32(byte3 & 0b0011_1111)

                codePoints.append(codePoint)
                index += 3

            } else if byte & 0b1111_1000 == 0b1111_0000 {
                // 4-byte sequence: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx (65536-1114111)
                guard index + 3 < bytes.count else { break }

                let byte1 = bytes[index]
                let byte2 = bytes[index + 1]
                let byte3 = bytes[index + 2]
                let byte4 = bytes[index + 3]

                let codePoint = (UInt32(byte1 & 0b0000_0111) << 18) |
                    (UInt32(byte2 & 0b0011_1111) << 12) |
                    (UInt32(byte3 & 0b0011_1111) << 6) |
                    UInt32(byte4 & 0b0011_1111)

                codePoints.append(codePoint)
                index += 4

            } else {
                // Invalid UTF-8 sequence - skip byte
                index += 1
            }
        }

        return codePoints
    }
}

// MARK: - UTF-16LE Encoder (Manual Implementation)

/// Manual UTF-16LE encoder for converting Unicode code points
///
/// Encodes Unicode code points into UTF-16 Little Endian bytes
/// without using Swift's String.unicodeScalars
enum UTF16LEEncoder {
    /// Encode Unicode code points to UTF-16LE bytes
    ///
    /// - Parameter codePoints: Array of Unicode code points
    /// - Returns: UTF-16LE encoded bytes
    static func encode(_ codePoints: [UInt32]) -> [UInt8] {
        var result: [UInt8] = []

        for codePoint in codePoints {
            if codePoint <= 0xFFFF {
                // BMP (Basic Multilingual Plane) - single 16-bit unit
                // Little Endian: low byte first, high byte second
                result.append(UInt8(codePoint & 0xFF)) // Low byte
                result.append(UInt8((codePoint >> 8) & 0xFF)) // High byte

            } else if codePoint <= 0x10FFFF {
                // Supplementary planes - surrogate pair needed
                let adjusted = codePoint - 0x10000
                let highSurrogate = 0xD800 + (adjusted >> 10)
                let lowSurrogate = 0xDC00 + (adjusted & 0x3FF)

                // High surrogate (Little Endian)
                result.append(UInt8(highSurrogate & 0xFF))
                result.append(UInt8((highSurrogate >> 8) & 0xFF))

                // Low surrogate (Little Endian)
                result.append(UInt8(lowSurrogate & 0xFF))
                result.append(UInt8((lowSurrogate >> 8) & 0xFF))
            }
            // Invalid code points (> 0x10FFFF) are skipped
        }

        return result
    }
}

// MARK: - String Encoding Conversion

public extension String {
    /// Преобразует строку в массив байт для заданной кодировки
    ///
    /// - Parameter encoding: Кодировка для преобразования
    /// - Returns: Массив байт
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello 世界"
    /// let asciiBytes = text.toBytes(encoding: .ascii)    // [72, 101, 108, 108, 111, 32]
    /// let utf8Bytes = text.toBytes(encoding: .utf8)      // Full UTF-8
    /// let utf16Bytes = text.toBytes(encoding: .utf16LE)  // UTF-16LE
    /// ```
    func toBytes(encoding: StringEncoding) -> [UInt8] {
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
    ///
    /// Non-ASCII символы отфильтровываются.
    ///
    /// - Returns: Массив ASCII байт
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello 世界"
    /// print(text.toASCIIBytes())  // [72, 101, 108, 108, 111, 32]
    /// // Chinese characters filtered out
    /// ```
    func toASCIIBytes() -> [UInt8] {
        return Array(utf8.filter { $0 < 128 })
    }

    /// Преобразует строку в UTF-8 байты
    ///
    /// - Returns: Массив UTF-8 байт
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello"
    /// print(text.toUTF8Bytes())  // [72, 101, 108, 108, 111]
    /// ```
    func toUTF8Bytes() -> [UInt8] {
        return Array(utf8)
    }

    /// Преобразует строку в UTF-16 Little Endian байты
    ///
    /// Поддерживает полный Unicode включая суррогатные пары.
    /// Использует ручную конвертацию UTF-8 → UTF-16LE без Foundation.
    ///
    /// - Returns: Массив UTF-16LE байт
    ///
    /// Example:
    /// ```swift
    /// let text = "A"  // U+0041
    /// print(text.toUTF16LEBytes())  // [65, 0] (little endian)
    ///
    /// let emoji = "😀"  // U+1F600 (requires surrogate pair)
    /// // [61, 216, 0, 222] - surrogate pair in little endian
    /// ```
    func toUTF16LEBytes() -> [UInt8] {
        // Step 1: Get UTF-8 bytes
        let utf8Bytes = Array(utf8)

        // Step 2: Decode UTF-8 to code points
        let codePoints = UTF8Decoder.decode(utf8Bytes)

        // Step 3: Encode code points to UTF-16LE
        let utf16Bytes = UTF16LEEncoder.encode(codePoints)

        return utf16Bytes
    }

    /// Вычисляет количество байт, которое займет строка в заданной кодировке
    ///
    /// Полезно для предварительного выделения памяти.
    ///
    /// - Parameter encoding: Кодировка для вычисления
    /// - Returns: Количество байт
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello"
    /// print(text.byteCount(for: .utf8))     // 5
    /// print(text.byteCount(for: .utf16LE))  // 10 (2 bytes per character)
    /// ```
    func byteCount(for encoding: StringEncoding) -> Int {
        switch encoding {
        case .ascii:
            return utf8.filter { $0 < 128 }.count
        case .utf8:
            return utf8.count
        case .utf16LE:
            // Calculate UTF-16LE size
            let utf8Bytes = Array(utf8)
            let codePoints = UTF8Decoder.decode(utf8Bytes)

            var count = 0
            for codePoint in codePoints {
                if codePoint <= 0xFFFF {
                    count += 2 // BMP character = 2 bytes
                } else {
                    count += 4 // Surrogate pair = 4 bytes
                }
            }
            return count
        }
    }
}

// MARK: - C API Integration

public extension String {
    /// Выполняет операцию с байтами строки в заданной кодировке
    ///
    /// Оптимизированная версия для прямой передачи в C API.
    ///
    /// - Parameters:
    ///   - encoding: Кодировка строки
    ///   - body: Замыкание, которое получает указатель на байты и их количество
    /// - Returns: Результат выполнения замыкания
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello"
    /// text.withCBytes(encoding: .utf8) { ptr, count in
    ///     // Pass ptr to C API
    ///     someC_Function(ptr, count)
    /// }
    /// ```
    func withCBytes<T>(
        encoding: StringEncoding = .utf8,
        _ body: (UnsafeRawPointer?, Int) -> T
    ) -> T {
        let bytes = toBytes(encoding: encoding)
        return bytes.withUnsafeBufferPointer { buffer in
            body(buffer.baseAddress, buffer.count)
        }
    }

    /// Создает null-terminated C строку для ASCII/UTF-8 кодировок
    ///
    /// - Parameter encoding: Кодировка (должна быть .ascii или .utf8)
    /// - Returns: Массив байт с завершающим нулем
    ///
    /// - Warning: UTF-16LE не поддерживается для C строк (возвращает пустой массив)
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello"
    /// let cstr = text.toCString()  // [72, 101, 108, 108, 111, 0]
    /// ```
    func toCString(encoding: StringEncoding = .utf8) -> [UInt8] {
        guard encoding == .ascii || encoding == .utf8 else {
            // UTF-16LE не подходит для C строк (null terminator conflicts)
            return []
        }

        var bytes = toBytes(encoding: encoding)
        bytes.append(0) // null terminator
        return bytes
    }

    /// Выполняет операцию с null-terminated C строкой
    ///
    /// - Parameter body: Замыкание, которое получает C string pointer
    /// - Returns: Результат выполнения замыкания
    ///
    /// Example:
    /// ```swift
    /// let result = "Hello".withCString { cstr in
    ///     strlen(cstr)  // C function
    /// }
    /// ```
    func withCString<Result>(
        _ body: (UnsafePointer<CChar>) -> Result
    ) -> Result {
        let bytes = toCString()
        return bytes.withUnsafeBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(
                to: CChar.self,
                capacity: buffer.count
            ) { cstr in
                body(cstr)
            }
        }
    }

    /// Выполняет операцию с mutable null-terminated C строкой
    ///
    /// - Parameter body: Замыкание, которое получает mutable C string pointer
    /// - Returns: Результат выполнения замыкания
    ///
    /// Example:
    /// ```swift
    /// var text = "Hello"
    /// text.withMutableCString { cstr in
    ///     // Modify C string in place
    ///     someC_MutatingFunction(cstr)
    /// }
    /// ```
    func withMutableCString<Result>(
        _ body: (UnsafeMutablePointer<CChar>) -> Result
    ) -> Result {
        var bytes = toCString()
        return bytes.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(
                to: CChar.self,
                capacity: buffer.count
            ) { cstr in
                body(cstr)
            }
        }
    }
}

// MARK: - Validation

public extension String {
    /// Проверяет, содержит ли строка только ASCII символы (0-127)
    ///
    /// - Returns: true если все символы ASCII
    ///
    /// Example:
    /// ```swift
    /// print("Hello".isASCII)    // true
    /// print("Hello 世界".isASCII) // false
    /// ```
    var isASCII: Bool {
        return utf8.allSatisfy { $0 < 128 }
    }

    /// Проверяет, может ли строка быть представлена в заданной кодировке без потерь
    ///
    /// - Parameter encoding: Кодировка для проверки
    /// - Returns: true если кодировка поддерживает все символы строки
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello 世界"
    /// print(text.canBeEncoded(in: .ascii))    // false
    /// print(text.canBeEncoded(in: .utf8))     // true
    /// print(text.canBeEncoded(in: .utf16LE))  // true
    /// ```
    func canBeEncoded(in encoding: StringEncoding) -> Bool {
        switch encoding {
        case .ascii:
            return isASCII
        case .utf8, .utf16LE:
            return true // UTF-8 и UTF-16 поддерживают весь Unicode
        }
    }

    /// Проверяет валидность UTF-8 последовательности
    ///
    /// - Returns: true если строка содержит валидный UTF-8
    ///
    /// Example:
    /// ```swift
    /// let valid = "Hello 世界"
    /// print(valid.isValidUTF8)  // true
    /// ```
    var isValidUTF8: Bool {
        let bytes = Array(utf8)
        let decoded = UTF8Decoder.decode(bytes)

        // Check if we can round-trip encode/decode
        // If any bytes were invalid, decoded array would be shorter
        return !decoded.isEmpty || isEmpty
    }

    /// Подсчитывает количество Unicode code points в строке
    ///
    /// - Returns: Количество code points (не байт, не графем)
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello"
    /// print(text.codePointCount)  // 5
    ///
    /// let emoji = "👨‍👩‍👧‍👦"  // Family emoji (multiple code points)
    /// print(emoji.codePointCount)  // 7 (man + ZWJ + woman + ZWJ + girl + ZWJ + boy)
    /// ```
    var codePointCount: Int {
        let bytes = Array(utf8)
        return UTF8Decoder.decode(bytes).count
    }

    /// Получить все Unicode code points строки
    ///
    /// - Returns: Массив code points (UInt32)
    ///
    /// Example:
    /// ```swift
    /// let text = "ABC"
    /// print(text.codePoints)  // [65, 66, 67]
    ///
    /// let emoji = "😀"
    /// print(emoji.codePoints)  // [128512] (0x1F600)
    /// ```
    var codePoints: [UInt32] {
        let bytes = Array(utf8)
        return UTF8Decoder.decode(bytes)
    }
}

// MARK: - String Construction from Code Points

public extension String {
    /// Создать строку из массива Unicode code points
    ///
    /// - Parameter codePoints: Массив Unicode code points
    /// - Returns: Строка или nil если code points невалидны
    ///
    /// Example:
    /// ```swift
    /// let text = String(codePoints: [72, 101, 108, 108, 111])
    /// print(text)  // "Hello"
    ///
    /// let emoji = String(codePoints: [128512])  // 0x1F600
    /// print(emoji)  // "😀"
    /// ```
    init?(codePoints: [UInt32]) {
        // Encode code points to UTF-8
        var utf8Bytes: [UInt8] = []

        for codePoint in codePoints {
            if codePoint <= 0x7F {
                // 1-byte sequence (ASCII)
                utf8Bytes.append(UInt8(codePoint))

            } else if codePoint <= 0x7FF {
                // 2-byte sequence
                utf8Bytes.append(UInt8(0b1100_0000 | (codePoint >> 6)))
                utf8Bytes.append(UInt8(0b1000_0000 | (codePoint & 0b0011_1111)))

            } else if codePoint <= 0xFFFF {
                // 3-byte sequence
                utf8Bytes.append(UInt8(0b1110_0000 | (codePoint >> 12)))
                utf8Bytes.append(UInt8(0b1000_0000 | ((codePoint >> 6) & 0b0011_1111)))
                utf8Bytes.append(UInt8(0b1000_0000 | (codePoint & 0b0011_1111)))

            } else if codePoint <= 0x10FFFF {
                // 4-byte sequence
                utf8Bytes.append(UInt8(0b1111_0000 | (codePoint >> 18)))
                utf8Bytes.append(UInt8(0b1000_0000 | ((codePoint >> 12) & 0b0011_1111)))
                utf8Bytes.append(UInt8(0b1000_0000 | ((codePoint >> 6) & 0b0011_1111)))
                utf8Bytes.append(UInt8(0b1000_0000 | (codePoint & 0b0011_1111)))

            } else {
                // Invalid code point
                return nil
            }
        }

        self = String(decoding: utf8Bytes, as: UTF8.self)
    }

    /// Создать строку из одного Unicode code point
    ///
    /// - Parameter codePoint: Unicode code point
    /// - Returns: Строка или nil если code point невалиден
    ///
    /// Example:
    /// ```swift
    /// let char = String(codePoint: 65)  // "A"
    /// let emoji = String(codePoint: 0x1F600)  // "😀"
    /// ```
    init?(codePoint: UInt32) {
        self.init(codePoints: [codePoint])
    }
}

// MARK: - String Substring Search (UTF-8 based)

public extension String {
    /// Check if string contains another string as substring
    ///
    /// Performs UTF-8 byte-by-byte search to find if the given
    /// substring exists within this string.
    ///
    /// - Parameter substring: The substring to search for
    /// - Returns: true if substring is found, false otherwise
    ///
    /// - Complexity: O(n*m) where n is the length of this string and
    ///               m is the length of the substring
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello, World!"
    /// print(text.contains("World"))  // true
    /// print(text.contains("world"))  // false (case-sensitive)
    /// print(text.contains("xyz"))    // false
    /// ```
    func contains(_ substring: String) -> Bool {
        // Empty substring is always found
        guard !substring.isEmpty else { return true }

        let sourceBytes = Array(utf8)
        let searchBytes = Array(substring.utf8)

        // Substring longer than string - can't contain it
        guard searchBytes.count <= sourceBytes.count else { return false }

        let maxStartIndex = sourceBytes.count - searchBytes.count

        // Search for substring using byte matching
        for startIndex in 0 ... maxStartIndex {
            var found = true

            // Check if substring matches at current position
            for offset in 0 ..< searchBytes.count {
                if sourceBytes[startIndex + offset] != searchBytes[offset] {
                    found = false
                    break
                }
            }

            if found {
                return true
            }
        }

        return false
    }

    /// Check if string starts with given prefix
    ///
    /// - Parameter prefix: The prefix to check for
    /// - Returns: true if string starts with prefix, false otherwise
    ///
    /// - Complexity: O(n) where n is prefix length
    ///
    /// Example:
    /// ```swift
    /// let path = "/System/Fonts/MyFont"
    /// print(path.hasPrefix("/System"))  // true
    /// print(path.hasPrefix("System"))   // false
    /// ```
    func hasPrefix(_ prefix: String) -> Bool {
        guard !prefix.isEmpty else { return true }

        let sourceBytes = Array(utf8)
        let prefixBytes = Array(prefix.utf8)

        guard prefixBytes.count <= sourceBytes.count else { return false }

        // Compare bytes from start
        for (index, byte) in prefixBytes.enumerated() {
            if sourceBytes[index] != byte {
                return false
            }
        }

        return true
    }

    /// Check if string ends with given suffix
    ///
    /// - Parameter suffix: The suffix to check for
    /// - Returns: true if string ends with suffix, false otherwise
    ///
    /// - Complexity: O(n) where n is suffix length
    ///
    /// Example:
    /// ```swift
    /// let filename = "font.pft"
    /// print(filename.hasSuffix(".pft"))  // true
    /// print(filename.hasSuffix(".png"))  // false
    /// ```
    func hasSuffix(_ suffix: String) -> Bool {
        guard !suffix.isEmpty else { return true }

        let sourceBytes = Array(utf8)
        let suffixBytes = Array(suffix.utf8)

        guard suffixBytes.count <= sourceBytes.count else { return false }

        let startIndex = sourceBytes.count - suffixBytes.count

        // Compare bytes from end
        for (offset, byte) in suffixBytes.enumerated() {
            if sourceBytes[startIndex + offset] != byte {
                return false
            }
        }

        return true
    }

    /// Find first occurrence of substring
    ///
    /// - Parameter substring: The substring to search for
    /// - Returns: Byte offset of first occurrence, or nil if not found
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello, World!"
    /// if let offset = text.firstIndex(of: "World") {
    ///     print("Found at byte offset: \(offset)")  // 7
    /// }
    /// ```
    func firstIndex(of substring: String) -> Int? {
        guard !substring.isEmpty else { return 0 }

        let sourceBytes = Array(utf8)
        let searchBytes = Array(substring.utf8)

        guard searchBytes.count <= sourceBytes.count else { return nil }

        let maxStartIndex = sourceBytes.count - searchBytes.count

        for startIndex in 0 ... maxStartIndex {
            var found = true

            for offset in 0 ..< searchBytes.count {
                if sourceBytes[startIndex + offset] != searchBytes[offset] {
                    found = false
                    break
                }
            }

            if found {
                return startIndex
            }
        }

        return nil
    }

    /// Find last occurrence of substring
    ///
    /// - Parameter substring: The substring to search for
    /// - Returns: Byte offset of last occurrence, or nil if not found
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello, Hello!"
    /// if let offset = text.lastIndex(of: "Hello") {
    ///     print("Last found at byte offset: \(offset)")  // 7
    /// }
    /// ```
    func lastIndex(of substring: String) -> Int? {
        guard !substring.isEmpty else { return utf8.count }

        let sourceBytes = Array(utf8)
        let searchBytes = Array(substring.utf8)

        guard searchBytes.count <= sourceBytes.count else { return nil }

        let maxStartIndex = sourceBytes.count - searchBytes.count

        // Search backwards
        for startIndex in stride(from: maxStartIndex, through: 0, by: -1) {
            var found = true

            for offset in 0 ..< searchBytes.count {
                if sourceBytes[startIndex + offset] != searchBytes[offset] {
                    found = false
                    break
                }
            }

            if found {
                return startIndex
            }
        }

        return nil
    }

    /// Count occurrences of substring
    ///
    /// - Parameter substring: The substring to count
    /// - Returns: Number of non-overlapping occurrences
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello Hello Hello"
    /// print(text.count(of: "Hello"))  // 3
    /// print(text.count(of: "xyz"))    // 0
    /// ```
    func count(of substring: String) -> Int {
        guard !substring.isEmpty else { return 0 }

        let sourceBytes = Array(utf8)
        let searchBytes = Array(substring.utf8)

        guard searchBytes.count <= sourceBytes.count else { return 0 }

        var count = 0
        var searchIndex = 0
        let maxStartIndex = sourceBytes.count - searchBytes.count

        while searchIndex <= maxStartIndex {
            var found = true

            for offset in 0 ..< searchBytes.count {
                if sourceBytes[searchIndex + offset] != searchBytes[offset] {
                    found = false
                    break
                }
            }

            if found {
                count += 1
                // Skip past this occurrence (non-overlapping)
                searchIndex += searchBytes.count
            } else {
                searchIndex += 1
            }
        }

        return count
    }
}

// MARK: - String Replacement (UTF-8 based)

public extension String {
    /// Replace all occurrences of target with replacement
    ///
    /// - Parameters:
    ///   - target: The substring to replace
    ///   - replacement: The replacement string
    /// - Returns: New string with replacements made
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello World, Hello Swift"
    /// let result = text.replacing("Hello", with: "Hi")
    /// print(result)  // "Hi World, Hi Swift"
    /// ```
    func replacing(_ target: String, with replacement: String) -> String {
        guard !target.isEmpty else { return self }
        guard contains(target) else { return self }

        let sourceBytes = Array(utf8)
        let targetBytes = Array(target.utf8)
        let replacementBytes = Array(replacement.utf8)

        var result: [UInt8] = []
        var searchIndex = 0

        while searchIndex < sourceBytes.count {
            // Check if target matches at current position
            if searchIndex + targetBytes.count <= sourceBytes.count {
                var found = true

                for offset in 0 ..< targetBytes.count {
                    if sourceBytes[searchIndex + offset] != targetBytes[offset] {
                        found = false
                        break
                    }
                }

                if found {
                    // Match found - add replacement
                    result.append(contentsOf: replacementBytes)
                    searchIndex += targetBytes.count
                    continue
                }
            }

            // No match - add original byte
            result.append(sourceBytes[searchIndex])
            searchIndex += 1
        }

        return String(decoding: result, as: UTF8.self)
    }

    /// Replace first occurrence of target with replacement
    ///
    /// - Parameters:
    ///   - target: The substring to replace
    ///   - replacement: The replacement string
    /// - Returns: New string with first replacement made
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello World, Hello Swift"
    /// let result = text.replacingFirst("Hello", with: "Hi")
    /// print(result)  // "Hi World, Hello Swift"
    /// ```
    func replacingFirst(_ target: String, with replacement: String) -> String {
        guard !target.isEmpty else { return self }
        guard let index = firstIndex(of: target) else { return self }

        let sourceBytes = Array(utf8)
        let targetBytes = Array(target.utf8)
        let replacementBytes = Array(replacement.utf8)

        var result: [UInt8] = []

        // Add bytes before match
        result.append(contentsOf: sourceBytes[0 ..< index])

        // Add replacement
        result.append(contentsOf: replacementBytes)

        // Add bytes after match
        let afterIndex = index + targetBytes.count
        if afterIndex < sourceBytes.count {
            result.append(contentsOf: sourceBytes[afterIndex ..< sourceBytes.count])
        }

        return String(decoding: result, as: UTF8.self)
    }
}

// MARK: - ASCII Case Conversion

public extension String {
    /// Convert ASCII string to lowercase
    ///
    /// - Returns: Lowercase version of the string
    ///
    /// - Note: Only handles ASCII characters (A-Z -> a-z)
    ///         Non-ASCII characters remain unchanged
    ///
    /// - Complexity: O(n) where n is byte count
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello WORLD"
    /// print(text.lowercasedASCII())  // "hello world"
    ///
    /// let mixed = "Hello 世界"
    /// print(mixed.lowercasedASCII())  // "hello 世界" (Chinese unchanged)
    /// ```
    func lowercasedASCII() -> String {
        let bytes = utf8.map { byte -> UInt8 in
            // Convert A-Z (65-90) to a-z (97-122)
            if byte >= 65 && byte <= 90 {
                return byte + 32
            }
            return byte
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Convert ASCII string to uppercase
    ///
    /// - Returns: Uppercase version of the string
    ///
    /// - Note: Only handles ASCII characters (a-z -> A-Z)
    ///         Non-ASCII characters remain unchanged
    ///
    /// - Complexity: O(n) where n is byte count
    ///
    /// Example:
    /// ```swift
    /// let text = "hello world"
    /// print(text.uppercasedASCII())  // "HELLO WORLD"
    ///
    /// let mixed = "hello 世界"
    /// print(mixed.uppercasedASCII())  // "HELLO 世界" (Chinese unchanged)
    /// ```
    func uppercasedASCII() -> String {
        let bytes = utf8.map { byte -> UInt8 in
            // Convert a-z (97-122) to A-Z (65-90)
            if byte >= 97 && byte <= 122 {
                return byte - 32
            }
            return byte
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Check if string contains another string (case-insensitive, ASCII only)
    ///
    /// - Parameter substring: The substring to search for
    /// - Returns: true if substring is found (ignoring case), false otherwise
    ///
    /// - Note: Only ASCII case folding is performed
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello, World!"
    /// print(text.containsIgnoringCaseASCII("world"))  // true
    /// print(text.containsIgnoringCaseASCII("HELLO"))  // true
    /// print(text.containsIgnoringCaseASCII("xyz"))    // false
    /// ```
    func containsIgnoringCaseASCII(_ substring: String) -> Bool {
        return lowercasedASCII().contains(substring.lowercasedASCII())
    }

    /// Check if string starts with prefix (case-insensitive, ASCII only)
    ///
    /// - Parameter prefix: The prefix to check for
    /// - Returns: true if string starts with prefix (ignoring case)
    ///
    /// Example:
    /// ```swift
    /// let path = "/System/Fonts"
    /// print(path.hasPrefixIgnoringCaseASCII("/system"))  // true
    /// ```
    func hasPrefixIgnoringCaseASCII(_ prefix: String) -> Bool {
        return lowercasedASCII().hasPrefix(prefix.lowercasedASCII())
    }

    /// Check if string ends with suffix (case-insensitive, ASCII only)
    ///
    /// - Parameter suffix: The suffix to check for
    /// - Returns: true if string ends with suffix (ignoring case)
    ///
    /// Example:
    /// ```swift
    /// let filename = "Font.PFT"
    /// print(filename.hasSuffixIgnoringCaseASCII(".pft"))  // true
    /// ```
    func hasSuffixIgnoringCaseASCII(_ suffix: String) -> Bool {
        return lowercasedASCII().hasSuffix(suffix.lowercasedASCII())
    }
}

// MARK: - String Comparison

public extension String {
    /// Compare strings ignoring ASCII case
    ///
    /// - Parameter other: String to compare with
    /// - Returns: true if strings are equal (case-insensitive)
    ///
    /// - Note: Only ASCII case folding is performed
    ///
    /// Example:
    /// ```swift
    /// print("Hello".equalsIgnoringCaseASCII("HELLO"))  // true
    /// print("Hello".equalsIgnoringCaseASCII("hello"))  // true
    /// print("Hello".equalsIgnoringCaseASCII("World"))  // false
    /// ```
    func equalsIgnoringCaseASCII(_ other: String) -> Bool {
        let bytes1 = Array(utf8)
        let bytes2 = Array(other.utf8)

        guard bytes1.count == bytes2.count else { return false }

        for (byte1, byte2) in zip(bytes1, bytes2) {
            // Convert both to lowercase for comparison
            let lower1 = (byte1 >= 65 && byte1 <= 90) ? byte1 + 32 : byte1
            let lower2 = (byte2 >= 65 && byte2 <= 90) ? byte2 + 32 : byte2

            if lower1 != lower2 {
                return false
            }
        }

        return true
    }

    /// Compare strings lexicographically
    ///
    /// - Parameter other: String to compare with
    /// - Returns: Comparison result (-1: less, 0: equal, 1: greater)
    ///
    /// Example:
    /// ```swift
    /// print("abc".compare(to: "def"))  // -1 (abc < def)
    /// print("xyz".compare(to: "abc"))  // 1  (xyz > abc)
    /// print("abc".compare(to: "abc"))  // 0  (equal)
    /// ```
    func compare(to other: String) -> Int {
        let bytes1 = Array(utf8)
        let bytes2 = Array(other.utf8)

        let minCount = min(bytes1.count, bytes2.count)

        for i in 0 ..< minCount {
            if bytes1[i] < bytes2[i] {
                return -1
            } else if bytes1[i] > bytes2[i] {
                return 1
            }
        }

        // All compared bytes are equal - check length
        if bytes1.count < bytes2.count {
            return -1
        } else if bytes1.count > bytes2.count {
            return 1
        } else {
            return 0
        }
    }

    /// Compare strings lexicographically (case-insensitive, ASCII only)
    ///
    /// - Parameter other: String to compare with
    /// - Returns: Comparison result (-1: less, 0: equal, 1: greater)
    ///
    /// Example:
    /// ```swift
    /// print("ABC".compareIgnoringCaseASCII(to: "def"))  // -1
    /// print("XYZ".compareIgnoringCaseASCII(to: "abc"))  // 1
    /// print("ABC".compareIgnoringCaseASCII(to: "abc"))  // 0
    /// ```
    func compareIgnoringCaseASCII(to other: String) -> Int {
        return lowercasedASCII().compare(to: other.lowercasedASCII())
    }
}

// MARK: - Character Classification

public extension String {
    /// Check if string contains only alphabetic ASCII characters (A-Z, a-z)
    ///
    /// - Returns: true if all characters are ASCII letters
    ///
    /// Example:
    /// ```swift
    /// print("Hello".isAlphabeticASCII)  // true
    /// print("Hello123".isAlphabeticASCII)  // false
    /// print("".isAlphabeticASCII)  // false
    /// ```
    var isAlphabeticASCII: Bool {
        guard !isEmpty else { return false }
        return utf8.allSatisfy { byte in
            (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)
        }
    }

    /// Check if string contains only numeric ASCII characters (0-9)
    ///
    /// - Returns: true if all characters are ASCII digits
    ///
    /// Example:
    /// ```swift
    /// print("12345".isNumericASCII)  // true
    /// print("123.45".isNumericASCII)  // false (contains dot)
    /// print("".isNumericASCII)  // false
    /// ```
    var isNumericASCII: Bool {
        guard !isEmpty else { return false }
        return utf8.allSatisfy { byte in
            byte >= 48 && byte <= 57 // 0-9
        }
    }

    /// Check if string contains only alphanumeric ASCII characters (A-Z, a-z, 0-9)
    ///
    /// - Returns: true if all characters are ASCII letters or digits
    ///
    /// Example:
    /// ```swift
    /// print("Hello123".isAlphanumericASCII)  // true
    /// print("Hello 123".isAlphanumericASCII)  // false (contains space)
    /// print("".isAlphanumericASCII)  // false
    /// ```
    var isAlphanumericASCII: Bool {
        guard !isEmpty else { return false }
        return utf8.allSatisfy { byte in
            (byte >= 48 && byte <= 57) || // 0-9
                (byte >= 65 && byte <= 90) || // A-Z
                (byte >= 97 && byte <= 122) // a-z
        }
    }

    /// Check if string contains only lowercase ASCII letters
    ///
    /// - Returns: true if all alphabetic characters are lowercase
    ///
    /// Example:
    /// ```swift
    /// print("hello".isLowercaseASCII)  // true
    /// print("Hello".isLowercaseASCII)  // false
    /// print("hello123".isLowercaseASCII)  // true (numbers ignored)
    /// ```
    var isLowercaseASCII: Bool {
        guard !isEmpty else { return false }
        var hasAlpha = false

        for byte in utf8 {
            if byte >= 65 && byte <= 90 {
                // Found uppercase letter
                return false
            }
            if byte >= 97 && byte <= 122 {
                // Found lowercase letter
                hasAlpha = true
            }
        }

        return hasAlpha
    }

    /// Check if string contains only uppercase ASCII letters
    ///
    /// - Returns: true if all alphabetic characters are uppercase
    ///
    /// Example:
    /// ```swift
    /// print("HELLO".isUppercaseASCII)  // true
    /// print("Hello".isUppercaseASCII)  // false
    /// print("HELLO123".isUppercaseASCII)  // true (numbers ignored)
    /// ```
    var isUppercaseASCII: Bool {
        guard !isEmpty else { return false }
        var hasAlpha = false

        for byte in utf8 {
            if byte >= 97 && byte <= 122 {
                // Found lowercase letter
                return false
            }
            if byte >= 65 && byte <= 90 {
                // Found uppercase letter
                hasAlpha = true
            }
        }

        return hasAlpha
    }
}

// MARK: - String Trimming

public extension String {
    /// Check if string is empty or contains only whitespace
    ///
    /// - Returns: true if string is empty or whitespace-only
    ///
    /// - Note: Checks for ASCII whitespace only (space, tab, newline, CR)
    ///
    /// Example:
    /// ```swift
    /// print("".isBlank)           // true
    /// print("   ".isBlank)        // true
    /// print("  a  ".isBlank)      // false
    /// print("\t\n\r".isBlank)     // true
    /// ```
    var isBlank: Bool {
        if isEmpty { return true }
        return utf8.allSatisfy { byte in
            // Check for common ASCII whitespace bytes:
            // space(32), tab(9), newline(10), carriage return(13)
            byte == 32 || byte == 9 || byte == 10 || byte == 13
        }
    }

    /// Trim whitespace from both ends of string
    ///
    /// - Returns: String with leading and trailing whitespace removed
    ///
    /// - Note: Only removes ASCII whitespace (space, tab, newline, CR)
    ///
    /// Example:
    /// ```swift
    /// let text = "  hello  "
    /// print(text.trimmedASCII())  // "hello"
    ///
    /// let multiline = "\n\t  text  \r\n"
    /// print(multiline.trimmedASCII())  // "text"
    /// ```
    func trimmedASCII() -> String {
        let bytes = Array(utf8)
        guard !bytes.isEmpty else { return "" }

        var start = 0
        var end = bytes.count - 1

        // Find first non-whitespace from start
        while start < bytes.count && isWhitespaceByte(bytes[start]) {
            start += 1
        }

        // Find first non-whitespace from end
        while end >= start && isWhitespaceByte(bytes[end]) {
            end -= 1
        }

        // If all whitespace
        if start > end {
            return ""
        }

        let trimmedBytes = Array(bytes[start ... end])
        return String(decoding: trimmedBytes, as: UTF8.self)
    }

    /// Trim whitespace from start of string
    ///
    /// - Returns: String with leading whitespace removed
    ///
    /// Example:
    /// ```swift
    /// let text = "  hello  "
    /// print(text.trimmedLeadingASCII())  // "hello  "
    /// ```
    func trimmedLeadingASCII() -> String {
        let bytes = Array(utf8)
        guard !bytes.isEmpty else { return "" }

        var start = 0

        // Find first non-whitespace from start
        while start < bytes.count && isWhitespaceByte(bytes[start]) {
            start += 1
        }

        if start >= bytes.count {
            return ""
        }

        let trimmedBytes = Array(bytes[start ..< bytes.count])
        return String(decoding: trimmedBytes, as: UTF8.self)
    }

    /// Trim whitespace from end of string
    ///
    /// - Returns: String with trailing whitespace removed
    ///
    /// Example:
    /// ```swift
    /// let text = "  hello  "
    /// print(text.trimmedTrailingASCII())  // "  hello"
    /// ```
    func trimmedTrailingASCII() -> String {
        let bytes = Array(utf8)
        guard !bytes.isEmpty else { return "" }

        var end = bytes.count - 1

        // Find first non-whitespace from end
        while end >= 0 && isWhitespaceByte(bytes[end]) {
            end -= 1
        }

        if end < 0 {
            return ""
        }

        let trimmedBytes = Array(bytes[0 ... end])
        return String(decoding: trimmedBytes, as: UTF8.self)
    }

    /// Check if byte is ASCII whitespace
    ///
    /// - Parameter byte: Byte to check
    /// - Returns: true if byte is whitespace
    private func isWhitespaceByte(_ byte: UInt8) -> Bool {
        // space(32), tab(9), newline(10), carriage return(13)
        return byte == 32 || byte == 9 || byte == 10 || byte == 13
    }
}

// MARK: - String Splitting

public extension String {
    /// Split string by separator byte
    ///
    /// - Parameter separatorByte: Single byte separator
    /// - Returns: Array of substrings
    ///
    /// - Note: Empty parts are included in result
    ///
    /// Example:
    /// ```swift
    /// let path = "/System/Fonts/MyFont"
    /// let parts = path.split(by: 47)  // 47 = '/'
    /// // ["", "System", "Fonts", "MyFont"]
    ///
    /// let csv = "a,b,c"
    /// let fields = csv.split(by: 44)  // 44 = ','
    /// // ["a", "b", "c"]
    /// ```
    func split(by separatorByte: UInt8) -> [String] {
        let bytes = Array(utf8)
        var result: [String] = []
        var currentStart = 0

        for (index, byte) in bytes.enumerated() {
            if byte == separatorByte {
                // Found separator - extract substring
                let part = Array(bytes[currentStart ..< index])
                result.append(String(decoding: part, as: UTF8.self))
                currentStart = index + 1
            }
        }

        // Add last part
        let lastPart = Array(bytes[currentStart ..< bytes.count])
        result.append(String(decoding: lastPart, as: UTF8.self))

        return result
    }

    /// Split string by separator string
    ///
    /// - Parameter separator: Separator string
    /// - Returns: Array of substrings
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello::World::Swift"
    /// let parts = text.split(by: "::")
    /// // ["Hello", "World", "Swift"]
    /// ```
    func split(by separator: String) -> [String] {
        guard !separator.isEmpty else { return [self] }
        guard contains(separator) else { return [self] }

        let sourceBytes = Array(utf8)
        let separatorBytes = Array(separator.utf8)

        var result: [String] = []
        var currentStart = 0
        var searchIndex = 0

        while searchIndex < sourceBytes.count {
            // Check if separator matches at current position
            if searchIndex + separatorBytes.count <= sourceBytes.count {
                var found = true

                for offset in 0 ..< separatorBytes.count {
                    if sourceBytes[searchIndex + offset] != separatorBytes[offset] {
                        found = false
                        break
                    }
                }

                if found {
                    // Found separator - extract part
                    let part = Array(sourceBytes[currentStart ..< searchIndex])
                    result.append(String(decoding: part, as: UTF8.self))

                    searchIndex += separatorBytes.count
                    currentStart = searchIndex
                    continue
                }
            }

            searchIndex += 1
        }

        // Add last part
        let lastPart = Array(sourceBytes[currentStart ..< sourceBytes.count])
        result.append(String(decoding: lastPart, as: UTF8.self))

        return result
    }

    /// Split string by newlines
    ///
    /// - Returns: Array of lines
    ///
    /// - Note: Both \n and \r\n are recognized as line endings
    ///
    /// Example:
    /// ```swift
    /// let text = "line1\nline2\nline3"
    /// let lines = text.lines()
    /// // ["line1", "line2", "line3"]
    ///
    /// let windows = "line1\r\nline2\r\nline3"
    /// let winLines = windows.lines()
    /// // ["line1", "line2", "line3"]
    /// ```
    func lines() -> [String] {
        let bytes = Array(utf8)
        var result: [String] = []
        var currentStart = 0
        var index = 0

        while index < bytes.count {
            if bytes[index] == 10 { // \n
                // Extract line
                let line = Array(bytes[currentStart ..< index])
                result.append(String(decoding: line, as: UTF8.self))
                currentStart = index + 1

            } else if bytes[index] == 13 { // \r
                // Check for \r\n
                if index + 1 < bytes.count, bytes[index + 1] == 10 {
                    // \r\n - skip both
                    let line = Array(bytes[currentStart ..< index])
                    result.append(String(decoding: line, as: UTF8.self))
                    index += 1 // Skip \n
                    currentStart = index + 1
                } else {
                    // Just \r
                    let line = Array(bytes[currentStart ..< index])
                    result.append(String(decoding: line, as: UTF8.self))
                    currentStart = index + 1
                }
            }

            index += 1
        }

        // Add last line if any
        if currentStart < bytes.count {
            let lastLine = Array(bytes[currentStart ..< bytes.count])
            result.append(String(decoding: lastLine, as: UTF8.self))
        }

        return result
    }

    /// Split string into words (separated by whitespace)
    ///
    /// - Returns: Array of words (non-empty, whitespace removed)
    ///
    /// Example:
    /// ```swift
    /// let text = "  Hello   World  Swift  "
    /// let words = text.words()
    /// // ["Hello", "World", "Swift"]
    /// ```
    func words() -> [String] {
        let bytes = Array(utf8)
        var result: [String] = []
        var currentStart = 0
        var inWord = false

        for (index, byte) in bytes.enumerated() {
            if isWhitespaceByte(byte) {
                if inWord {
                    // End of word
                    let word = Array(bytes[currentStart ..< index])
                    result.append(String(decoding: word, as: UTF8.self))
                    inWord = false
                }
            } else {
                if !inWord {
                    // Start of word
                    currentStart = index
                    inWord = true
                }
            }
        }

        // Add last word if any
        if inWord {
            let lastWord = Array(bytes[currentStart ..< bytes.count])
            result.append(String(decoding: lastWord, as: UTF8.self))
        }

        return result
    }
}

// MARK: - String Padding

public extension String {
    /// Pad string to specified length with character on the left
    ///
    /// - Parameters:
    ///   - length: Target byte length
    ///   - paddingByte: Byte to use for padding (default: space)
    /// - Returns: Padded string
    ///
    /// Example:
    /// ```swift
    /// let num = "42"
    /// print(num.paddedLeft(toLength: 5, with: 48))  // "00042" (48 = '0')
    /// print(num.paddedLeft(toLength: 5))  // "   42" (default space)
    /// ```
    func paddedLeft(toLength length: Int, with paddingByte: UInt8 = 32) -> String {
        let bytes = Array(utf8)

        if bytes.count >= length {
            return self
        }

        let paddingCount = length - bytes.count
        var result = [UInt8](repeating: paddingByte, count: paddingCount)
        result.append(contentsOf: bytes)

        return String(decoding: result, as: UTF8.self)
    }

    /// Pad string to specified length with character on the right
    ///
    /// - Parameters:
    ///   - length: Target byte length
    ///   - paddingByte: Byte to use for padding (default: space)
    /// - Returns: Padded string
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello"
    /// print(text.paddedRight(toLength: 10))  // "Hello     "
    /// print(text.paddedRight(toLength: 10, with: 46))  // "Hello....." (46 = '.')
    /// ```
    func paddedRight(toLength length: Int, with paddingByte: UInt8 = 32) -> String {
        let bytes = Array(utf8)

        if bytes.count >= length {
            return self
        }

        let paddingCount = length - bytes.count
        var result = bytes
        result.append(contentsOf: [UInt8](repeating: paddingByte, count: paddingCount))

        return String(decoding: result, as: UTF8.self)
    }
}

// MARK: - ASCII Constants

/// ASCII character code constants for common characters
public enum ASCIICode {
    // Control characters
    public static let null: UInt8 = 0
    public static let tab: UInt8 = 9
    public static let lineFeed: UInt8 = 10 // \n
    public static let carriageReturn: UInt8 = 13 // \r
    public static let escape: UInt8 = 27

    // Whitespace
    public static let space: UInt8 = 32

    // Punctuation and symbols
    public static let exclamation: UInt8 = 33 // !
    public static let doubleQuote: UInt8 = 34 // "
    public static let hash: UInt8 = 35 // #
    public static let dollar: UInt8 = 36 // $
    public static let percent: UInt8 = 37 // %
    public static let ampersand: UInt8 = 38 // &
    public static let singleQuote: UInt8 = 39 // '
    public static let leftParen: UInt8 = 40 // (
    public static let rightParen: UInt8 = 41 // )
    public static let asterisk: UInt8 = 42 // *
    public static let plus: UInt8 = 43 // +
    public static let comma: UInt8 = 44 // ,
    public static let minus: UInt8 = 45 // -
    public static let period: UInt8 = 46 // .
    public static let slash: UInt8 = 47 // /

    // Digits
    public static let digit0: UInt8 = 48 // 0
    public static let digit1: UInt8 = 49 // 1
    public static let digit2: UInt8 = 50 // 2
    public static let digit3: UInt8 = 51 // 3
    public static let digit4: UInt8 = 52 // 4
    public static let digit5: UInt8 = 53 // 5
    public static let digit6: UInt8 = 54 // 6
    public static let digit7: UInt8 = 55 // 7
    public static let digit8: UInt8 = 56 // 8
    public static let digit9: UInt8 = 57 // 9

    // More symbols
    public static let colon: UInt8 = 58 // :
    public static let semicolon: UInt8 = 59 // ;
    public static let lessThan: UInt8 = 60 // <
    public static let equals: UInt8 = 61 // =
    public static let greaterThan: UInt8 = 62 // >
    public static let question: UInt8 = 63 // ?
    public static let at: UInt8 = 64 // @

    // Uppercase letters
    public static let upperA: UInt8 = 65 // A
    public static let upperB: UInt8 = 66 // B
    public static let upperC: UInt8 = 67 // C
    public static let upperD: UInt8 = 68 // D
    public static let upperE: UInt8 = 69 // E
    public static let upperF: UInt8 = 70 // F
    public static let upperG: UInt8 = 71 // G
    public static let upperH: UInt8 = 72 // H
    public static let upperI: UInt8 = 73 // I
    public static let upperJ: UInt8 = 74 // J
    public static let upperK: UInt8 = 75 // K
    public static let upperL: UInt8 = 76 // L
    public static let upperM: UInt8 = 77 // M
    public static let upperN: UInt8 = 78 // N
    public static let upperO: UInt8 = 79 // O
    public static let upperP: UInt8 = 80 // P
    public static let upperQ: UInt8 = 81 // Q
    public static let upperR: UInt8 = 82 // R
    public static let upperS: UInt8 = 83 // S
    public static let upperT: UInt8 = 84 // T
    public static let upperU: UInt8 = 85 // U
    public static let upperV: UInt8 = 86 // V
    public static let upperW: UInt8 = 87 // W
    public static let upperX: UInt8 = 88 // X
    public static let upperY: UInt8 = 89 // Y
    public static let upperZ: UInt8 = 90 // Z

    // Brackets and braces
    public static let leftBracket: UInt8 = 91 // [
    public static let backslash: UInt8 = 92 // \
    public static let rightBracket: UInt8 = 93 // ]
    public static let caret: UInt8 = 94 // ^
    public static let underscore: UInt8 = 95 // _
    public static let backtick: UInt8 = 96 // `

    // Lowercase letters
    public static let lowerA: UInt8 = 97 // a
    public static let lowerB: UInt8 = 98 // b
    public static let lowerC: UInt8 = 99 // c
    public static let lowerD: UInt8 = 100 // d
    public static let lowerE: UInt8 = 101 // e
    public static let lowerF: UInt8 = 102 // f
    public static let lowerG: UInt8 = 103 // g
    public static let lowerH: UInt8 = 104 // h
    public static let lowerI: UInt8 = 105 // i
    public static let lowerJ: UInt8 = 106 // j
    public static let lowerK: UInt8 = 107 // k
    public static let lowerL: UInt8 = 108 // l
    public static let lowerM: UInt8 = 109 // m
    public static let lowerN: UInt8 = 110 // n
    public static let lowerO: UInt8 = 111 // o
    public static let lowerP: UInt8 = 112 // p
    public static let lowerQ: UInt8 = 113 // q
    public static let lowerR: UInt8 = 114 // r
    public static let lowerS: UInt8 = 115 // s
    public static let lowerT: UInt8 = 116 // t
    public static let lowerU: UInt8 = 117 // u
    public static let lowerV: UInt8 = 118 // v
    public static let lowerW: UInt8 = 119 // w
    public static let lowerX: UInt8 = 120 // x
    public static let lowerY: UInt8 = 121 // y
    public static let lowerZ: UInt8 = 122 // z

    // More brackets
    public static let leftBrace: UInt8 = 123 // {
    public static let pipe: UInt8 = 124 // |
    public static let rightBrace: UInt8 = 125 // }
    public static let tilde: UInt8 = 126 // ~
    public static let delete: UInt8 = 127
}

// MARK: - Character Code Utilities

public extension String {
    /// Convert string to array of ASCII character codes
    ///
    /// - Returns: Array of UInt8 character codes
    ///
    /// Example:
    /// ```swift
    /// let text = "ABC"
    /// print(text.asciiCodes)  // [65, 66, 67]
    /// ```
    var asciiCodes: [UInt8] {
        return Array(utf8)
    }

    /// Get ASCII code of first character
    ///
    /// - Returns: ASCII code or nil if empty
    ///
    /// Example:
    /// ```swift
    /// print("A".firstASCIICode)  // 65
    /// print("".firstASCIICode)   // nil
    /// ```
    var firstASCIICode: UInt8? {
        return utf8.first
    }

    /// Get ASCII code of last character
    ///
    /// - Returns: ASCII code or nil if empty
    ///
    /// Example:
    /// ```swift
    /// print("ABC".lastASCIICode)  // 67
    /// print("".lastASCIICode)     // nil
    /// ```
    var lastASCIICode: UInt8? {
        return utf8.last
    }

    /// Create string from single ASCII code
    ///
    /// - Parameter code: ASCII character code
    ///
    /// Example:
    /// ```swift
    /// let char = String(asciiCode: 65)  // "A"
    /// let space = String(asciiCode: ASCIICode.space)  // " "
    /// ```
    init(asciiCode: UInt8) {
        self = String(decoding: [asciiCode], as: UTF8.self)
    }

    /// Create string from array of ASCII codes
    ///
    /// - Parameter codes: Array of ASCII character codes
    ///
    /// Example:
    /// ```swift
    /// let text = String(asciiCodes: [65, 66, 67])  // "ABC"
    /// ```
    init(asciiCodes: [UInt8]) {
        self = String(decoding: asciiCodes, as: UTF8.self)
    }

    /// Create string by repeating ASCII code
    ///
    /// - Parameters:
    ///   - code: ASCII character code to repeat
    ///   - count: Number of repetitions
    ///
    /// Example:
    /// ```swift
    /// let stars = String(repeating: ASCIICode.asterisk, count: 10)  // "**********"
    /// let spaces = String(repeating: ASCIICode.space, count: 5)     // "     "
    /// ```
    init(repeating code: UInt8, count: Int) {
        let bytes = [UInt8](repeating: code, count: count)
        self = String(decoding: bytes, as: UTF8.self)
    }
}

// MARK: - Hexadecimal Conversion

public extension String {
    /// Convert string to hexadecimal representation
    ///
    /// - Parameter uppercase: Use uppercase letters (default: true)
    /// - Returns: Hex string
    ///
    /// Example:
    /// ```swift
    /// let text = "ABC"
    /// print(text.toHex())  // "414243"
    /// print(text.toHex(uppercase: false))  // "414243"
    /// ```
    func toHex(uppercase: Bool = true) -> String {
        let hexDigits = uppercase ?
            Array("0123456789ABCDEF".utf8) :
            Array("0123456789abcdef".utf8)

        var result: [UInt8] = []

        for byte in utf8 {
            let high = Int(byte >> 4)
            let low = Int(byte & 0x0F)
            result.append(hexDigits[high])
            result.append(hexDigits[low])
        }

        return String(decoding: result, as: UTF8.self)
    }

    /// Create string from hexadecimal representation
    ///
    /// - Parameter hex: Hexadecimal string (e.g., "414243")
    /// - Returns: Decoded string or nil if invalid hex
    ///
    /// Example:
    /// ```swift
    /// let text = String(hex: "414243")  // "ABC"
    /// let invalid = String(hex: "XYZ")  // nil
    /// ```
    init?(hex: String) {
        let hexBytes = Array(hex.utf8)

        // Hex string must have even length
        guard hexBytes.count % 2 == 0 else { return nil }

        var result: [UInt8] = []
        var index = 0

        while index < hexBytes.count {
            let highNibble = hexBytes[index]
            let lowNibble = hexBytes[index + 1]

            guard let highValue = Self.hexValue(of: highNibble),
                  let lowValue = Self.hexValue(of: lowNibble)
            else {
                return nil
            }

            let byte = (highValue << 4) | lowValue
            result.append(byte)

            index += 2
        }

        self = String(decoding: result, as: UTF8.self)
    }

    /// Convert hex digit character to value
    private static func hexValue(of byte: UInt8) -> UInt8? {
        switch byte {
        case 48 ... 57: // 0-9
            return byte - 48
        case 65 ... 70: // A-F
            return byte - 65 + 10
        case 97 ... 102: // a-f
            return byte - 97 + 10
        default:
            return nil
        }
    }
}

// MARK: - String Repetition

public extension String {
    /// Repeat string n times
    ///
    /// - Parameter count: Number of repetitions
    /// - Returns: Repeated string
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello"
    /// print(text.repeated(3))  // "HelloHelloHello"
    ///
    /// let separator = "-"
    /// print(separator.repeated(20))  // "--------------------"
    /// ```
    func repeated(_ count: Int) -> String {
        guard count > 0 else { return "" }
        guard count > 1 else { return self }

        let bytes = Array(utf8)
        var result: [UInt8] = []
        result.reserveCapacity(bytes.count * count)

        for _ in 0 ..< count {
            result.append(contentsOf: bytes)
        }

        return String(decoding: result, as: UTF8.self)
    }

    /// Repeat string n times with separator
    ///
    /// - Parameters:
    ///   - count: Number of repetitions
    ///   - separator: Separator between repetitions
    /// - Returns: Repeated string with separators
    ///
    /// Example:
    /// ```swift
    /// let text = "A"
    /// print(text.repeated(5, separatedBy: "-"))  // "A-A-A-A-A"
    /// ```
    func repeated(_ count: Int, separatedBy separator: String) -> String {
        guard count > 0 else { return "" }
        guard count > 1 else { return self }

        let bytes = Array(utf8)
        let separatorBytes = Array(separator.utf8)

        var result: [UInt8] = []

        for i in 0 ..< count {
            result.append(contentsOf: bytes)

            // Add separator except after last element
            if i < count - 1 {
                result.append(contentsOf: separatorBytes)
            }
        }

        return String(decoding: result, as: UTF8.self)
    }
}

// MARK: - String Reversing

public extension String {
    /// Reverse string at byte level
    ///
    /// - Returns: Reversed string
    ///
    /// - Warning: This reverses UTF-8 bytes, not Unicode graphemes.
    ///            Multi-byte characters will be corrupted!
    ///            Only safe for ASCII strings.
    ///
    /// Example:
    /// ```swift
    /// let text = "Hello"
    /// print(text.reversedBytes())  // "olleH"
    ///
    /// let unsafe = "Hello 世界"
    /// print(unsafe.reversedBytes())  // Corrupted! (multi-byte chars broken)
    /// ```
    func reversedBytes() -> String {
        let bytes = Array(utf8.reversed())
        return String(decoding: bytes, as: UTF8.self)
    }
}

// MARK: - EOF Marker

/// End of StringUtils.swift
///
/// Summary:
/// - String encoding support (ASCII, UTF-8, UTF-16LE)
/// - C API integration
/// - String search and manipulation (UTF-8 based)
/// - ASCII case conversion
/// - String trimming and splitting
/// - Character code utilities
/// - Hexadecimal conversion
/// - String repetition and reversal
///
/// All implementations are Foundation-free and optimized for Playdate SDK
