// BitmapTable.swift
// Playdate Graphics Swift SDK
//
// Wrapper for LCDBitmapTable* with automatic memory management
// Represents a collection of bitmaps for animations, tilesets, and sprite sheets

import CPlaydate

// MARK: - Graphics API Accessor

/// Access to Playdate graphics C API
private var graphicsAPI: playdate_graphics {
    playdateAPI.graphics.unsafelyUnwrapped.pointee
}

// MARK: - BitmapTable Class

/// Represents a collection of bitmaps in Playdate graphics system
///
/// BitmapTable is typically used for:
/// - **Sprite animations** - Sequential frames for character movement
/// - **Tile sets** - Collection of tiles for tilemaps
/// - **UI element collections** - Buttons, icons, indicators
/// - **Sprite sheets** - Grid-based image atlases
///
/// # Important Lifecycle Notes
///
/// ⚠️ **CRITICAL - Bitmap Lifetime Warning**
///
/// From Playdate SDK documentation:
/// > "freeBitmapTable() will invalidate any bitmaps returned by getTableBitmap()"
///
/// This means:
/// - Bitmaps retrieved from table are **BORROWED** (not owned)
/// - They become **INVALID** when the table is deallocated
/// - Accessing them after table dealloc = undefined behavior or crash
///
/// # Safe Usage Patterns
///
/// ```swift
/// // ✅ SAFE: Use bitmaps within table's scope
/// func drawSprite() {
///     let table = BitmapTable.load("sprites").get()
///     table[0]?.draw(at: .zero)
///     // table deallocates here, but we're done with bitmap
/// }
///
/// // ❌ UNSAFE: Don't store borrowed bitmaps
/// class Player {
///     var sprite: Bitmap?  // ⚠️ Danger!
///
///     func loadSprite() {
///         let table = BitmapTable.load("player").get()
///         self.sprite = table[0]  // ⚠️ Borrowed bitmap!
///         // table deallocates here - sprite is now INVALID!
///     }
///
///     func draw() {
///         sprite?.draw(at: position)  // 💥 CRASH - invalid bitmap!
///     }
/// }
///
/// // ✅ SAFE: Copy if you need to keep bitmap
/// class Player {
///     var sprite: Bitmap?
///
///     func loadSprite() {
///         let table = BitmapTable.load("player").get()
///         if let borrowed = table[0] {
///             self.sprite = try? Bitmap.copy(from: borrowed).get()
///             // sprite is now owned and safe to keep
///         }
///     }
/// }
///
/// // ✅ SAFE: Keep table alive
/// class SpriteManager {
///     let table: BitmapTable  // Keep table in memory
///
///     init() {
///         self.table = BitmapTable.load("sprites").get()
///     }
///
///     func getSprite(_ index: Int32) -> Bitmap? {
///         return table[index]  // Safe - table is still alive
///     }
/// }
/// ```
///
/// # Image Table File Format
///
/// Image tables are created from grid-based PNG files with naming pattern:
/// ```
/// <name>-table-<width>-<height>.png
/// ```
///
/// Examples:
/// - `player-table-32-32.png` - Creates table of 32x32 sprites
/// - `tiles-table-16-16.png` - Creates table of 16x16 tiles
/// - `enemies-table-48-48.png` - Creates table of 48x48 enemy sprites
///
/// The SDK automatically:
/// - Detects grid layout from image dimensions
/// - Splits image into individual bitmaps
/// - Calculates `cellsWide` (cells across) and row count
///
/// For a 128x64 image with 32x32 cells:
/// - cellsWide = 4 (128 / 32)
/// - rows = 2 (64 / 32)
/// - count = 8 total bitmaps
///
public final class BitmapTable {
    // MARK: - Private Properties

    /// Pointer to underlying LCDBitmapTable C structure
    private let pointer: OpaquePointer

    /// Ownership type - determines if table should be freed in deinit
    private let ownership: Ownership

    /// Original file path (if loaded from file)
    private let sourcePath: String?

    /// Total number of bitmaps in table (cached at creation)
    private let _count: Int32

    /// Number of cells across in sprite sheet grid (lazy loaded)
    /// - Note: From SDK: "number of cells across" in getBitmapTableInfo
    private var _cellsWide: Int32?

    /// Individual bitmap dimensions (lazy loaded from first bitmap)
    private var _bitmapWidth: Int32?
    private var _bitmapHeight: Int32?

    /// Ownership model for table memory management
    private enum Ownership {
        case owned // We created/loaded it, we free it in deinit
        case borrowed // System owns it, don't free in deinit
    }

    // MARK: - Private Initialization

    /// Internal unsafe initializer - assumes pointer is valid
    /// - Parameters:
    ///   - ownedPointer: Valid LCDBitmapTable pointer (will be freed)
    ///   - sourcePath: Original file path if loaded from file
    ///   - count: Number of bitmaps in table
    private init(ownedPointer ptr: OpaquePointer, sourcePath: String?, count: Int32) {
        pointer = ptr
        ownership = .owned
        self.sourcePath = sourcePath
        _count = count
    }

    /// Internal initializer for borrowed table pointer (system owned)
    /// - Parameters:
    ///   - borrowedPointer: Pointer to system-owned table (won't be freed)
    ///   - count: Number of bitmaps in table
    private init(borrowedPointer: OpaquePointer, count: Int32) {
        pointer = borrowedPointer
        ownership = .borrowed
        sourcePath = nil
        _count = count
    }

    /// Deinitializer - frees owned tables
    deinit {
        if ownership == .owned {
            // Free the C bitmap table structure
            // This invalidates ALL bitmaps obtained from this table
            graphicsAPI.freeBitmapTable(pointer)
        }
        // borrowed tables are not freed - system manages them
    }

    /// Internal access to C pointer for C API operations
    var cPointer: OpaquePointer {
        return pointer
    }
}

// MARK: - Static Factory Methods - Creation

public extension BitmapTable {
    /// Create a new bitmap table with specified count and dimensions
    ///
    /// Allocates a table that can hold `count` bitmaps, each of size `width x height`.
    /// All bitmaps are initially empty (clear).
    ///
    /// - Parameters:
    ///   - count: Number of bitmaps to allocate (must be > 0)
    ///   - width: Width of each bitmap in pixels (must be > 0)
    ///   - height: Height of each bitmap in pixels (must be > 0)
    /// - Returns: Result with BitmapTable on success or GraphicsError on failure
    ///
    /// From Playdate SDK:
    /// > "Allocates and returns a new LCDBitmapTable that can hold count
    /// > width by height LCDBitmaps."
    ///
    /// Example:
    /// ```swift
    /// // Create table for 10 animation frames of 32x32
    /// switch BitmapTable.create(count: 10, width: 32, height: 32) {
    /// case .success(let table):
    ///     print("Created table with \(table.count) bitmaps")
    ///
    ///     // Fill each frame with different content
    ///     for i in 0..<table.count {
    ///         if let bitmap = table[i] {
    ///             bitmap.clear(color: i % 2 == 0 ? .white : .black)
    ///         }
    ///     }
    ///
    /// case .failure(let error):
    ///     print("Failed to create table: \(error)")
    /// }
    /// ```
    static func create(
        count: Int32,
        width: Int32,
        height: Int32
    ) -> Result<BitmapTable, GraphicsError> {
        // Validate parameters
        guard count > 0 else {
            return .failure(.bitmapTableCreationFailed(
                count: count,
                width: width,
                height: height
            ))
        }

        guard width > 0, height > 0 else {
            return .failure(.invalidDimensions(width: width, height: height))
        }

        // Allocate table via C API
        guard let ptr = graphicsAPI.newBitmapTable(count, width, height) else {
            return .failure(.memoryAllocationFailed(
                operation: "bitmap table creation \(count) x (\(width)x\(height))",
                size: count * width * height / 8
            ))
        }

        return .success(BitmapTable(
            ownedPointer: ptr,
            sourcePath: nil,
            count: count
        ))
    }
}

// MARK: - Static Factory Methods - Loading

public extension BitmapTable {
    /// Load bitmap table from file
    ///
    /// Loads an image table from a file in the Playdate imagetable format.
    ///
    /// - Parameter path: Path to image table file (relative to project root)
    /// - Returns: Result with BitmapTable on success or GraphicsError on failure
    ///
    /// From Playdate SDK:
    /// > "If there is no file at path, the function returns null."
    ///
    /// # Image Table File Format
    ///
    /// Image tables use the naming pattern:
    /// ```
    /// <name>-table-<width>-<height>.png
    /// ```
    ///
    /// The SDK automatically:
    /// - Parses the grid dimensions from filename
    /// - Splits the image into individual bitmaps
    /// - Creates table with appropriate count and cellsWide
    ///
    /// Example:
    /// ```swift
    /// // Load sprite animation: "player-table-32-32.png"
    /// switch BitmapTable.load(path: "images/player-table-32-32") {
    /// case .success(let table):
    ///     print("Loaded \(table.count) sprites")
    ///     print("Grid: \(table.cellsWide ?? 0) cells wide")
    ///     print("Each sprite: \(table.bitmapWidth ?? 0)x\(table.bitmapHeight ?? 0)")
    ///
    ///     // Use first sprite
    ///     table[0]?.draw(at: .zero)
    ///
    /// case .failure(let error):
    ///     print("Failed to load table: \(error)")
    /// }
    /// ```
    static func load(path: String) -> Result<BitmapTable, GraphicsError> {
        var errorPtr: UnsafePointer<CChar>?

        // Load table via C API
        guard let ptr = graphicsAPI.loadBitmapTable(path, &errorPtr) else {
            let errorMessage = errorPtr.map { String(cString: $0) }
                ?? "File not found or invalid format"
            return .failure(.bitmapTableLoadFailed(
                path: path,
                reason: errorMessage
            ))
        }

        // Get table info to determine count
        var count: Int32 = 0
        var cellsWide: Int32 = 0
        graphicsAPI.getBitmapTableInfo(ptr, &count, &cellsWide)

        let table = BitmapTable(
            ownedPointer: ptr,
            sourcePath: path,
            count: count
        )

        // Cache cellsWide from load
        table._cellsWide = cellsWide

        return .success(table)
    }

    /// Load bitmap table data into existing table
    ///
    /// Reloads image table from file into a previously allocated table.
    /// Useful for hot-reloading assets during development or runtime content updates.
    ///
    /// - Parameter path: Path to image table file
    /// - Returns: Result with success or GraphicsError on failure
    ///
    /// From Playdate SDK:
    /// > "Loads the imagetable at path into the previously allocated table."
    ///
    /// - Important: The new image must have compatible dimensions with the
    ///              existing table (same count and bitmap sizes).
    ///
    /// Example:
    /// ```swift
    /// // Create empty table
    /// let table = BitmapTable.create(count: 10, width: 32, height: 32).get()
    ///
    /// // Later, load actual content
    /// switch table.loadInto(path: "images/sprites-table-32-32") {
    /// case .success:
    ///     print("Table reloaded successfully")
    ///
    /// case .failure(let error):
    ///     print("Reload failed: \(error)")
    /// }
    ///
    /// // Development hot-reload pattern
    /// #if DEBUG
    /// func reloadAssets() {
    ///     _ = spriteTable.loadInto(path: "sprites-table-32-32")
    /// }
    /// #endif
    /// ```
    func loadInto(path: String) -> Result<Void, GraphicsError> {
        var errorPtr: UnsafePointer<CChar>?

        // Load into existing table via C API
        graphicsAPI.loadIntoBitmapTable(path, pointer, &errorPtr)

        if let error = errorPtr {
            let errorMessage = String(cString: error)
            return .failure(.bitmapTableLoadFailed(
                path: path,
                reason: errorMessage
            ))
        }

        // Update cached info after reload
        updateTableInfo()

        return .success(())
    }
}

// MARK: - Convenience Failable Initializers

public extension BitmapTable {
    /// Convenience failable initializer for creating bitmap table
    ///
    /// - Parameters:
    ///   - count: Number of bitmaps
    ///   - width: Width of each bitmap
    ///   - height: Height of each bitmap
    /// - Returns: BitmapTable instance or nil if creation fails
    ///
    /// Example:
    /// ```swift
    /// if let table = BitmapTable(count: 5, width: 16, height: 16) {
    ///     // Use table
    /// }
    /// ```
    convenience init?(count: Int32, width: Int32, height: Int32) {
        guard count > 0, width > 0, height > 0 else {
            return nil
        }

        guard let ptr = graphicsAPI.newBitmapTable(count, width, height) else {
            return nil
        }

        self.init(ownedPointer: ptr, sourcePath: nil, count: count)
    }

    /// Convenience failable initializer for loading bitmap table
    ///
    /// - Parameter path: Path to image table file
    /// - Returns: BitmapTable instance or nil if load fails
    ///
    /// Example:
    /// ```swift
    /// if let table = BitmapTable(path: "sprites-table-32-32") {
    ///     table[0]?.draw(at: .zero)
    /// }
    /// ```
    convenience init?(path: String) {
        var errorPtr: UnsafePointer<CChar>?

        guard let ptr = graphicsAPI.loadBitmapTable(path, &errorPtr) else {
            return nil
        }

        // Get count
        var count: Int32 = 0
        var cellsWide: Int32 = 0
        graphicsAPI.getBitmapTableInfo(ptr, &count, &cellsWide)

        self.init(ownedPointer: ptr, sourcePath: path, count: count)
        _cellsWide = cellsWide
    }
}

// MARK: - Bitmap Access via Subscript

public extension BitmapTable {
    /// Unsafe subscript access to bitmap by index
    ///
    /// Returns a borrowed bitmap at the specified index, or nil if out of bounds.
    ///
    /// - Parameter index: Bitmap index (0-based, must be in range 0..<count)
    /// - Returns: Borrowed bitmap or nil if index out of bounds
    ///
    /// From Playdate SDK:
    /// > "Returns the idx bitmap in table. If idx is out of bounds,
    /// > the function returns NULL."
    ///
    /// ⚠️ **CRITICAL LIFETIME WARNING**
    ///
    /// The returned bitmap is **BORROWED** from this table and becomes
    /// **INVALID** when the table is deallocated.
    ///
    /// From SDK documentation:
    /// > "freeBitmapTable() will invalidate any bitmaps returned by getTableBitmap()"
    ///
    /// # Important Rules
    ///
    /// - ✅ DO: Use bitmap immediately within table's scope
    /// - ✅ DO: Copy bitmap if you need to keep it (Bitmap.copy)
    /// - ❌ DON'T: Store borrowed bitmap beyond table lifetime
    /// - ❌ DON'T: Free borrowed bitmap separately
    ///
    /// # Performance Note
    ///
    /// This subscript is **fast** but provides no error details.
    /// For detailed error information, use `table[safe: index]` instead.
    ///
    /// Example:
    /// ```swift
    /// let table = BitmapTable.load("sprites-table-32-32").get()
    ///
    /// // ✅ SAFE: Immediate use within scope
    /// if let sprite = table[0] {
    ///     sprite.draw(at: .zero)
    /// }
    ///
    /// // ✅ SAFE: Animation loop
    /// for i in 0..<table.count {
    ///     if let frame = table[i] {
    ///         frame.draw(at: position)
    ///     }
    /// }
    ///
    /// // ❌ UNSAFE: Storing borrowed bitmap
    /// class Player {
    ///     var sprite: Bitmap?
    ///
    ///     func loadSprite() {
    ///         let table = BitmapTable(path: "player")!
    ///         self.sprite = table[0]  // ⚠️ Dangling reference!
    ///         // table deallocates here
    ///     }
    ///
    ///     func draw() {
    ///         sprite?.draw(at: pos)  // 💥 CRASH - invalid bitmap
    ///     }
    /// }
    ///
    /// // ✅ SAFE: Copy for storage
    /// class Player {
    ///     var sprite: Bitmap?
    ///
    ///     func loadSprite() {
    ///         let table = BitmapTable(path: "player")!
    ///         if let borrowed = table[0],
    ///            case .success(let owned) = Bitmap.copy(from: borrowed) {
    ///             self.sprite = owned  // Safe - we own it
    ///         }
    ///     }
    /// }
    ///
    /// // ✅ SAFE: Keep table alive
    /// class SpriteSheet {
    ///     let table: BitmapTable  // Keep table in memory
    ///
    ///     init(path: String) {
    ///         self.table = BitmapTable.load(path).get()
    ///     }
    ///
    ///     func getFrame(_ index: Int32) -> Bitmap? {
    ///         return table[index]  // Safe - table still alive
    ///     }
    /// }
    /// ```
    subscript(index: Int32) -> Bitmap? {
        // Validate index range
        guard index >= 0, index < _count else {
            return nil
        }

        // Get bitmap from C API
        // Returns NULL if index out of bounds (already validated above)
        guard let bitmapPtr = graphicsAPI.getTableBitmap(pointer, Int32(index)) else {
            return nil
        }

        // Return borrowed bitmap - not owned by caller
        // ⚠️ This bitmap becomes invalid when table is freed
        return Bitmap(borrowedPointer: bitmapPtr)
    }

    /// Safe subscript with detailed error information
    ///
    /// Returns a Result containing either a borrowed bitmap or a detailed error.
    /// Use this when you need explicit error handling.
    ///
    /// - Parameter index: Bitmap index (0-based)
    /// - Returns: Result with borrowed bitmap or GraphicsError
    ///
    /// ⚠️ Same lifetime warnings apply as regular subscript.
    ///
    /// Example:
    /// ```swift
    /// switch table[safe: 5] {
    /// case .success(let bitmap):
    ///     bitmap.draw(at: Point(x: 10, y: 10))
    ///
    /// case .failure(.invalidBitmapIndex(let idx, let count)):
    ///     print("Index \(idx) out of range 0..<\(count)")
    ///
    /// case .failure(let error):
    ///     print("Unexpected error: \(error)")
    /// }
    ///
    /// // Propagate errors with Result
    /// func drawSprite(at index: Int32) -> Result<Void, GraphicsError> {
    ///     let bitmap = try table[safe: index].get()
    ///     bitmap.draw(at: .zero)
    ///     return .success(())
    /// }
    /// ```
    subscript(safe index: Int32) -> Result<Bitmap, GraphicsError> {
        return getBitmap(at: index)
    }

    /// Get bitmap at index with detailed error handling
    ///
    /// - Parameter index: Bitmap index (0-based)
    /// - Returns: Result with borrowed bitmap or GraphicsError
    ///
    /// ⚠️ Returned bitmap is borrowed and follows same lifetime rules.
    ///
    /// Example:
    /// ```swift
    /// switch table.getBitmap(at: 0) {
    /// case .success(let bitmap):
    ///     // Use bitmap
    ///     bitmap.draw(at: .zero)
    ///
    /// case .failure(let error):
    ///     print("Failed to get bitmap: \(error)")
    /// }
    /// ```
    func getBitmap(at index: Int32) -> Result<Bitmap, GraphicsError> {
        // Validate index range
        guard index >= 0, index < _count else {
            return .failure(.invalidBitmapIndex(index: index, count: _count))
        }

        // Get bitmap from C API
        guard let bitmapPtr = graphicsAPI.getTableBitmap(pointer, Int32(index)) else {
            // This shouldn't happen if index is valid, but handle gracefully
            return .failure(.nullPointerReturned(
                function: "getTableBitmap",
                reason: "Unexpected NULL for valid index \(index)"
            ))
        }

        // Return borrowed bitmap
        return .success(Bitmap(borrowedPointer: bitmapPtr))
    }
}

// MARK: - Public Properties

public extension BitmapTable {
    /// Total number of bitmaps in this table
    ///
    /// This value is fixed at table creation and doesn't change.
    ///
    /// Example:
    /// ```swift
    /// let table = BitmapTable.load("sprites-table-32-32").get()
    /// print("Table contains \(table.count) sprites")
    ///
    /// // Safe iteration
    /// for i in 0..<table.count {
    ///     table[i]?.draw(at: Point(x: i * 32, y: 0))
    /// }
    /// ```
    var count: Int32 {
        return _count
    }

    /// Number of cells across in the sprite sheet grid
    ///
    /// For image tables loaded from files, this represents the horizontal
    /// cell count in the original grid layout.
    ///
    /// From Playdate SDK:
    /// > getBitmapTableInfo returns "number of cells across" (cellswide)
    ///
    /// Example:
    /// ```swift
    /// // For "enemies-table-32-32.png" (128x64 image):
    /// let table = BitmapTable.load("enemies-table-32-32").get()
    /// print("Cells wide: \(table.cellsWide ?? 0)")  // 4 (128 / 32)
    /// print("Rows: \(table.rows ?? 0)")              // 2 (64 / 32)
    /// print("Total: \(table.count)")                 // 8 bitmaps
    ///
    /// // Use for grid-based rendering
    /// if let cellsWide = table.cellsWide {
    ///     for i in 0..<table.count {
    ///         let x = (i % cellsWide) * 32
    ///         let y = (i / cellsWide) * 32
    ///         table[i]?.draw(at: Point(x: x, y: y))
    ///     }
    /// }
    /// ```
    var cellsWide: Int32? {
        if _cellsWide == nil {
            updateTableInfo()
        }
        return _cellsWide
    }

    /// Number of rows in the sprite sheet grid (computed)
    ///
    /// Calculated from count and cellsWide using ceiling division.
    ///
    /// Example:
    /// ```swift
    /// // For an 8-sprite table with 3 cells wide:
    /// // Row 0: [0, 1, 2]
    /// // Row 1: [3, 4, 5]
    /// // Row 2: [6, 7, -]  (last cell empty)
    /// // rows = 3
    ///
    /// if let rows = table.rows, let cellsWide = table.cellsWide {
    ///     for row in 0..<rows {
    ///         for col in 0..<cellsWide {
    ///             let index = row * cellsWide + col
    ///             if index < table.count {
    ///                 table[index]?.draw(at: Point(x: col * 32, y: row * 32))
    ///             }
    ///         }
    ///     }
    /// }
    /// ```
    var rows: Int32? {
        guard let cellsWide = cellsWide, cellsWide > 0 else {
            return nil
        }
        // Ceiling division: (count + cellsWide - 1) / cellsWide
        return (_count + cellsWide - 1) / cellsWide
    }

    /// Individual bitmap dimensions as Size (if uniform)
    ///
    /// Returns the size of bitmaps in this table, or nil if unable to determine.
    /// Dimensions are obtained from the first bitmap in the table.
    ///
    /// Example:
    /// ```swift
    /// if let size = table.bitmapSize {
    ///     print("Each sprite: \(size.width)x\(size.height)")
    /// }
    /// ```
    var bitmapSize: Size? {
        guard let width = bitmapWidth, let height = bitmapHeight else {
            return nil
        }
        return Size(width: width, height: height)
    }

    /// Width of individual bitmaps in pixels
    ///
    /// Lazy loaded from first bitmap in table.
    ///
    /// Example:
    /// ```swift
    /// if let width = table.bitmapWidth {
    ///     print("Sprite width: \(width)px")
    /// }
    /// ```
    var bitmapWidth: Int32? {
        if _bitmapWidth == nil {
            updateBitmapDimensions()
        }
        return _bitmapWidth
    }

    /// Height of individual bitmaps in pixels
    ///
    /// Lazy loaded from first bitmap in table.
    ///
    /// Example:
    /// ```swift
    /// if let height = table.bitmapHeight {
    ///     print("Sprite height: \(height)px")
    /// }
    /// ```
    var bitmapHeight: Int32? {
        if _bitmapHeight == nil {
            updateBitmapDimensions()
        }
        return _bitmapHeight
    }

    /// Original file path if table was loaded from file
    ///
    /// Returns nil for tables created programmatically.
    ///
    /// Example:
    /// ```swift
    /// if let path = table.path {
    ///     print("Loaded from: \(path)")
    /// } else {
    ///     print("Created programmatically")
    /// }
    /// ```
    var path: String? {
        return sourcePath
    }

    /// Check if this is an owned table (will be freed in deinit)
    ///
    /// Example:
    /// ```swift
    /// if table.isOwned {
    ///     print("This table will be freed automatically")
    /// }
    /// ```
    var isOwned: Bool {
        return ownership == .owned
    }

    /// Check if this is a borrowed table (system owned, not freed in deinit)
    ///
    /// Example:
    /// ```swift
    /// if table.isBorrowed {
    ///     print("This table is managed by the system")
    /// }
    /// ```
    var isBorrowed: Bool {
        return ownership == .borrowed
    }

    /// Valid index range for this table
    ///
    /// Useful for safe iteration and bounds checking.
    ///
    /// Example:
    /// ```swift
    /// for index in table.indices {
    ///     table[index]?.draw(at: Point(x: index * 32, y: 0))
    /// }
    ///
    /// // Check if index is valid
    /// if table.indices.contains(5) {
    ///     let bitmap = table[5]
    /// }
    /// ```
    var indices: Range<Int32> {
        return 0 ..< _count
    }

    /// Check if table is empty (contains no bitmaps)
    ///
    /// Example:
    /// ```swift
    /// if table.isEmpty {
    ///     print("No sprites available")
    /// }
    /// ```
    var isEmpty: Bool {
        return _count == 0
    }
}

// MARK: - Collection-like Methods

public extension BitmapTable {
    /// Get all bitmaps from the table as an array
    ///
    /// ⚠️ All returned bitmaps are borrowed and follow standard lifetime rules.
    ///
    /// - Returns: Array of borrowed bitmaps (may contain fewer than count if some are invalid)
    ///
    /// Example:
    /// ```swift
    /// let allSprites = table.getAllBitmaps()
    /// for (index, sprite) in allSprites.enumerated() {
    ///     sprite.draw(at: Point(x: Int32(index) * 32, y: 0))
    /// }
    /// ```
    func getAllBitmaps() -> [Bitmap] {
        var bitmaps: [Bitmap] = []
        bitmaps.reserveCapacity(Int(_count))

        for i in 0 ..< _count {
            if let bitmap = self[i] {
                bitmaps.append(bitmap)
            }
        }

        return bitmaps
    }

    /// Execute closure for each bitmap in the table
    ///
    /// ⚠️ Bitmaps passed to closure are borrowed and follow standard lifetime rules.
    ///
    /// - Parameter body: Closure to execute with each bitmap and its index
    ///
    /// Example:
    /// ```swift
    /// // Draw all sprites in a row
    /// table.forEachBitmap { bitmap, index in
    ///     bitmap.draw(at: Point(x: index * 32, y: 0))
    /// }
    ///
    /// // With grid layout
    /// table.forEachBitmap { bitmap, index in
    ///     if let cellsWide = table.cellsWide {
    ///         let col = index % cellsWide
    ///         let row = index / cellsWide
    ///         bitmap.draw(at: Point(x: col * 32, y: row * 32))
    ///     }
    /// }
    /// ```
    func forEachBitmap(_ body: (Bitmap, Int32) -> Void) {
        for i in 0 ..< _count {
            if let bitmap = self[i] {
                body(bitmap, i)
            }
        }
    }

    /// Check if index is valid for this table
    ///
    /// - Parameter index: Index to validate
    /// - Returns: true if index is in valid range (0..<count)
    ///
    /// Example:
    /// ```swift
    /// if table.isValidIndex(5) {
    ///     let bitmap = table[5]!  // Safe to force unwrap
    /// }
    /// ```
    func isValidIndex(_ index: Int32) -> Bool {
        return index >= 0 && index < _count
    }
}

// MARK: - Memory Management

public extension BitmapTable {
    /// Automatic cleanup - frees table if owned
    ///
    /// ⚠️ **CRITICAL WARNING FROM PLAYDATE SDK**
    ///
    /// > "freeBitmapTable() will invalidate any bitmaps returned by getTableBitmap()"
    ///
    /// When a BitmapTable is deallocated:
    /// - The C API frees the underlying LCDBitmapTable structure
    /// - **ALL** bitmaps retrieved from this table become **INVALID**
    /// - Accessing those bitmaps = undefined behavior or crash
    ///
    /// # Safe Patterns
    ///
    /// ```swift
    /// // ✅ SAFE: Table and bitmaps in same scope
    /// func drawFrame() {
    ///     let table = BitmapTable.load("anim").get()
    ///     table[0]?.draw(at: .zero)
    ///     // table and bitmap deallocate together - safe
    /// }
    ///
    /// // ❌ UNSAFE: Bitmap outlives table
    /// var sprite: Bitmap?
    /// func loadSprite() {
    ///     let table = BitmapTable.load("player").get()
    ///     sprite = table[0]
    ///     // table deallocates here
    /// }
    /// func draw() {
    ///     sprite?.draw(at: pos)  // 💥 CRASH - sprite is invalid
    /// }
    ///
    /// // ✅ SAFE: Copy bitmap for storage
    /// var sprite: Bitmap?
    /// func loadSprite() {
    ///     let table = BitmapTable.load("player").get()
    ///     if let borrowed = table[0] {
    ///         sprite = try? Bitmap.copy(from: borrowed).get()
    ///         // sprite is now owned and independent
    ///     }
    /// }
    ///
    /// // ✅ SAFE: Keep table alive as long as needed
    /// class AnimationPlayer {
    ///     let table: BitmapTable  // Keep table in memory
    ///     var currentFrame: Int32 = 0
    ///
    ///     init(path: String) {
    ///         self.table = BitmapTable.load(path).get()
    ///     }
    ///
    ///     func draw() {
    ///         table[currentFrame]?.draw(at: position)
    ///         // Safe - table is still alive
    ///     }
    /// }
    /// ```
}

// MARK: - Private Helpers

private extension BitmapTable {
    /// Update cached table information from C API
    ///
    /// Fetches count and cellsWide from the underlying C structure.
    /// Called lazily when cellsWide is first accessed or after loadInto().
    func updateTableInfo() {
        var count: Int32 = 0
        var cellsWide: Int32 = 0

        graphicsAPI.getBitmapTableInfo(pointer, &count, &cellsWide)

        // Update cached values
        // Note: _count is let (immutable), so we don't update it
        _cellsWide = cellsWide
    }

    /// Update cached bitmap dimensions from first bitmap
    ///
    /// Gets dimensions by querying the first bitmap in the table.
    /// Called lazily when bitmapWidth/bitmapHeight are first accessed.
    func updateBitmapDimensions() {
        // Try to get first bitmap
        guard _count > 0,
              let firstBitmap = self[0]
        else {
            return
        }

        // Cache dimensions from first bitmap
        _bitmapWidth = firstBitmap.width
        _bitmapHeight = firstBitmap.height
    }
}

// MARK: - Equatable

extension BitmapTable: Equatable {
    /// Compare two bitmap tables for equality
    ///
    /// Tables are considered equal if:
    /// 1. They point to the same underlying C table (identity), OR
    /// 2. They have the same count and source path
    ///
    /// - Note: This does NOT compare individual bitmap content for
    ///         performance reasons on resource-constrained Playdate hardware.
    ///
    /// Example:
    /// ```swift
    /// let table1 = BitmapTable.load("sprites").get()
    /// let table2 = BitmapTable.load("sprites").get()
    ///
    /// // Different instances, but same source
    /// print(table1 == table2)  // false (different pointers)
    ///
    /// let table3 = table1
    /// print(table1 == table3)  // true (same pointer)
    /// ```
    public static func == (lhs: BitmapTable, rhs: BitmapTable) -> Bool {
        // First check: pointer identity (same C table)
        if lhs.pointer == rhs.pointer {
            return true
        }

        // Second check: same count and source path
        // (different instances of same loaded table)
        if lhs._count == rhs._count,
           lhs.sourcePath == rhs.sourcePath,
           lhs.sourcePath != nil
        {
            return true
        }

        return false
    }
}

// MARK: - Hashable

extension BitmapTable: Hashable {
    /// Hash bitmap table based on pointer identity
    ///
    /// Allows tables to be used in Sets and as Dictionary keys.
    ///
    /// Example:
    /// ```swift
    /// var tableCache: Set<BitmapTable> = []
    /// var animationMap: [BitmapTable: String] = [:]
    ///
    /// let playerTable = BitmapTable.load("player").get()
    /// tableCache.insert(playerTable)
    /// animationMap[playerTable] = "idle"
    /// ```
    public func hash(into hasher: inout Hasher) {
        // Hash based on pointer address for identity-based hashing
        hasher.combine(Int(bitPattern: pointer))
    }
}

// MARK: - CustomStringConvertible

extension BitmapTable: CustomStringConvertible {
    /// Human-readable description of the bitmap table
    ///
    /// Shows count, grid layout, bitmap dimensions, and file path.
    ///
    /// Example outputs:
    /// - `"BitmapTable(8 bitmaps, 4x2 grid, 32x32px, path: "sprites-table-32-32")"`
    /// - `"BitmapTable(10 bitmaps, 32x32px)"`
    /// - `"BitmapTable(5 bitmaps)"`
    public var description: String {
        var parts: [String] = []

        // Count
        parts.append("\(_count) bitmap\(_count == 1 ? "" : "s")")

        // Grid layout (if available)
        if let cellsWide = _cellsWide, let rows = rows {
            parts.append("\(cellsWide)x\(rows) grid")
        }

        // Bitmap dimensions (if available)
        if let width = _bitmapWidth, let height = _bitmapHeight {
            parts.append("\(width)x\(height)px")
        }

        // Source path (if loaded from file)
        if let path = sourcePath {
            parts.append("path: \"\(path)\"")
        }

        let details = parts.joined(separator: ", ")
        return "BitmapTable(\(details))"
    }
}

// MARK: - Utility Methods

public extension BitmapTable {
    /// Check if table contains a specific bitmap (by reference)
    ///
    /// - Parameter bitmap: Bitmap to search for
    /// - Returns: true if bitmap is found in table
    ///
    /// - Note: Uses pointer comparison, not content comparison
    ///
    /// Example:
    /// ```swift
    /// let sprite = table[0]!
    /// if table.contains(bitmap: sprite) {
    ///     print("Sprite is from this table")
    /// }
    /// ```
    func contains(bitmap: Bitmap) -> Bool {
        for i in 0 ..< _count {
            if let tableBitmap = self[i],
               tableBitmap == bitmap
            {
                return true
            }
        }
        return false
    }

    /// Find index of bitmap in table (by reference)
    ///
    /// - Parameter bitmap: Bitmap to search for
    /// - Returns: Index of bitmap or nil if not found
    ///
    /// Example:
    /// ```swift
    /// let sprite = table[3]!
    /// if let index = table.indexOf(bitmap: sprite) {
    ///     print("Sprite is at index \(index)")
    /// }
    /// ```
    func indexOf(bitmap: Bitmap) -> Int32? {
        for i in 0 ..< _count {
            if let tableBitmap = self[i],
               tableBitmap == bitmap
            {
                return i
            }
        }
        return nil
    }

    /// Get bitmap safely with default fallback
    ///
    /// - Parameters:
    ///   - index: Bitmap index
    ///   - default: Bitmap to return if index is invalid
    /// - Returns: Bitmap at index or default
    ///
    /// Example:
    /// ```swift
    /// let fallback = Bitmap(width: 32, height: 32)!
    /// let sprite = table.getBitmap(at: 5, default: fallback)
    /// sprite.draw(at: .zero)  // Always has a valid bitmap
    /// ```
    func getBitmap(at index: Int32, default defaultBitmap: Bitmap) -> Bitmap {
        return self[index] ?? defaultBitmap
    }

    /// Calculate total memory size of all bitmaps in table
    ///
    /// - Returns: Approximate total memory size in bytes
    ///
    /// Example:
    /// ```swift
    /// let memoryUsage = table.totalMemorySize
    /// print("Table uses ~\(memoryUsage) bytes")
    /// ```
    var totalMemorySize: Int32 {
        guard let width = bitmapWidth,
              let height = bitmapHeight
        else {
            return 0
        }

        // Each bitmap: (width * height) / 8 bits per pixel
        let bytesPerBitmap = (width * height) / 8
        return bytesPerBitmap * _count
    }

    /// Check if all bitmaps in table have uniform dimensions
    ///
    /// - Returns: true if all bitmaps have same size
    ///
    /// Example:
    /// ```swift
    /// if table.hasUniformDimensions {
    ///     print("All sprites are \(table.bitmapWidth!)x\(table.bitmapHeight!)")
    /// } else {
    ///     print("Sprites have varying sizes")
    /// }
    /// ```
    var hasUniformDimensions: Bool {
        guard let expectedWidth = bitmapWidth,
              let expectedHeight = bitmapHeight
        else {
            return false
        }

        // Check all bitmaps
        for i in 0 ..< _count {
            guard let bitmap = self[i] else { continue }

            if bitmap.width != expectedWidth ||
                bitmap.height != expectedHeight
            {
                return false
            }
        }

        return true
    }
}

// MARK: - Animation Support

public extension BitmapTable {
    /// Animation sequence helper
    ///
    /// Provides convenient access to sequential frames for animations.
    ///
    /// Example:
    /// ```swift
    /// class Character {
    ///     let walkCycle = BitmapTable.load("walk-cycle").get()
    ///     var frameIndex: Int32 = 0
    ///
    ///     func update() {
    ///         frameIndex = walkCycle.nextFrame(after: frameIndex)
    ///     }
    ///
    ///     func draw() {
    ///         walkCycle[frameIndex]?.draw(at: position)
    ///     }
    /// }
    /// ```
    struct AnimationSequence {
        let table: BitmapTable
        let startFrame: Int32
        let frameCount: Int32
        let loop: Bool

        /// Get frame at offset from start
        func frame(at offset: Int32) -> Bitmap? {
            let index = startFrame + offset
            guard index >= startFrame,
                  index < startFrame + frameCount
            else {
                return nil
            }
            return table[index]
        }

        /// Get next frame index with looping
        func nextFrame(after current: Int32) -> Int32 {
            let next = current + 1
            let relativeNext = next - startFrame

            if relativeNext >= frameCount {
                return loop ? startFrame : (startFrame + frameCount - 1)
            }

            return next
        }

        /// Get previous frame index with looping
        func previousFrame(before current: Int32) -> Int32 {
            let prev = current - 1

            if prev < startFrame {
                return loop ? (startFrame + frameCount - 1) : startFrame
            }

            return prev
        }
    }

    /// Create animation sequence from range of frames
    ///
    /// - Parameters:
    ///   - startFrame: First frame index
    ///   - frameCount: Number of frames in sequence
    ///   - loop: Whether to loop back to start
    /// - Returns: AnimationSequence helper
    ///
    /// Example:
    /// ```swift
    /// let table = BitmapTable.load("character-animations").get()
    ///
    /// // Walk cycle: frames 0-7
    /// let walkCycle = table.animationSequence(
    ///     startFrame: 0,
    ///     frameCount: 8,
    ///     loop: true
    /// )
    ///
    /// // Jump: frames 8-11 (no loop)
    /// let jumpAnim = table.animationSequence(
    ///     startFrame: 8,
    ///     frameCount: 4,
    ///     loop: false
    /// )
    /// ```
    func animationSequence(
        startFrame: Int32,
        frameCount: Int32,
        loop: Bool = true
    ) -> AnimationSequence {
        return AnimationSequence(
            table: self,
            startFrame: startFrame,
            frameCount: frameCount,
            loop: loop
        )
    }

    /// Get next frame index with wrapping
    ///
    /// - Parameter current: Current frame index
    /// - Returns: Next frame index, wrapping to 0 after last frame
    ///
    /// Example:
    /// ```swift
    /// var frame: Int32 = 0
    ///
    /// func animate() {
    ///     frame = table.nextFrame(after: frame)
    ///     table[frame]?.draw(at: position)
    /// }
    /// ```
    func nextFrame(after current: Int32) -> Int32 {
        let next = current + 1
        return next >= _count ? 0 : next
    }

    /// Get previous frame index with wrapping
    ///
    /// - Parameter current: Current frame index
    /// - Returns: Previous frame index, wrapping to last after 0
    ///
    /// Example:
    /// ```swift
    /// var frame: Int32 = 0
    ///
    /// func reverseAnimate() {
    ///     frame = table.previousFrame(before: frame)
    ///     table[frame]?.draw(at: position)
    /// }
    /// ```
    func previousFrame(before current: Int32) -> Int32 {
        let prev = current - 1
        return prev < 0 ? (_count - 1) : prev
    }

    /// Calculate frame index from animation time
    ///
    /// - Parameters:
    ///   - time: Current animation time in seconds
    ///   - fps: Frames per second (animation speed)
    ///   - loop: Whether to loop animation
    /// - Returns: Frame index for current time
    ///
    /// Example:
    /// ```swift
    /// class AnimatedSprite {
    ///     let table: BitmapTable
    ///     var animationTime: Float = 0
    ///     let fps: Float = 12  // 12 frames per second
    ///
    ///     func update(deltaTime: Float) {
    ///         animationTime += deltaTime
    ///
    ///         let frameIndex = table.frameAtTime(
    ///             animationTime,
    ///             fps: fps,
    ///             loop: true
    ///         )
    ///
    ///         table[frameIndex]?.draw(at: position)
    ///     }
    /// }
    /// ```
    func frameAtTime(_ time: Float, fps: Float, loop: Bool = true) -> Int32 {
        let totalFrames = Float(_count)
        let frameIndex = Int32(time * fps)

        if loop {
            return frameIndex % _count
        } else {
            return min(frameIndex, _count - 1)
        }
    }

    /// Calculate animation duration in seconds
    ///
    /// - Parameter fps: Frames per second
    /// - Returns: Total animation duration
    ///
    /// Example:
    /// ```swift
    /// let duration = table.animationDuration(fps: 12)
    /// print("Animation length: \(duration) seconds")
    /// ```
    func animationDuration(fps: Float) -> Float {
        return Float(_count) / fps
    }
}

// MARK: - Grid Operations

public extension BitmapTable {
    /// Get bitmap at grid position
    ///
    /// - Parameters:
    ///   - column: Column index (0-based)
    ///   - row: Row index (0-based)
    /// - Returns: Bitmap at grid position or nil
    ///
    /// Example:
    /// ```swift
    /// // For a 4x2 sprite grid:
    /// let sprite = table.bitmapAt(column: 2, row: 1)
    /// // Gets bitmap at index: 1 * 4 + 2 = 6
    /// ```
    func bitmapAt(column: Int32, row: Int32) -> Bitmap? {
        guard let cellsWide = cellsWide else {
            return nil
        }

        let index = row * cellsWide + column
        return self[index]
    }

    /// Get grid position for bitmap index
    ///
    /// - Parameter index: Bitmap index
    /// - Returns: (column, row) tuple or nil
    ///
    /// Example:
    /// ```swift
    /// if let (col, row) = table.gridPosition(for: 6) {
    ///     print("Bitmap 6 is at column \(col), row \(row)")
    /// }
    /// ```
    func gridPosition(for index: Int32) -> (column: Int32, row: Int32)? {
        guard let cellsWide = cellsWide,
              isValidIndex(index)
        else {
            return nil
        }

        let column = index % cellsWide
        let row = index / cellsWide

        return (column, row)
    }

    /// Draw entire grid of bitmaps
    ///
    /// - Parameters:
    ///   - origin: Top-left position to start drawing
    ///   - spacing: Space between bitmaps (default: 0)
    ///
    /// Example:
    /// ```swift
    /// // Draw all sprites in grid layout
    /// table.drawGrid(at: Point(x: 10, y: 10), spacing: 2)
    /// ```
    func drawGrid(at origin: Point, spacing: Int32 = 0) {
        guard let cellsWide = cellsWide,
              let width = bitmapWidth,
              let height = bitmapHeight
        else {
            return
        }

        let cellWidth = width + spacing
        let cellHeight = height + spacing

        for i in 0 ..< _count {
            let column = i % cellsWide
            let row = i / cellsWide

            let x = origin.x + (column * cellWidth)
            let y = origin.y + (row * cellHeight)

            self[i]?.draw(at: Point(x: x, y: y))
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
    public extension BitmapTable {
        /// Detailed debug information about the table
        ///
        /// Example:
        /// ```swift
        /// print(table.debugInfo)
        /// // Output:
        /// // BitmapTable Debug Info:
        /// //   Pointer: 0x12345678
        /// //   Ownership: owned
        /// //   Count: 8 bitmaps
        /// //   Grid: 4x2 (4 cells wide, 2 rows)
        /// //   Bitmap Size: 32x32px
        /// //   Total Memory: ~1024 bytes
        /// //   Source: images/sprites-table-32-32
        /// //   Valid indices: 0..<8
        /// ```
        var debugInfo: String {
            var lines: [String] = []

            lines.append("BitmapTable Debug Info:")
            lines.append("  Pointer: \(pointer)")
            lines.append("  Ownership: \(ownership == .owned ? "owned" : "borrowed")")
            lines.append("  Count: \(_count) bitmap\(_count == 1 ? "" : "s")")

            if let cellsWide = _cellsWide, let rows = rows {
                lines.append("  Grid: \(cellsWide)x\(rows) (\(cellsWide) cells wide, \(rows) rows)")
            }

            if let width = _bitmapWidth, let height = _bitmapHeight {
                lines.append("  Bitmap Size: \(width)x\(height)px")
                let memSize = totalMemorySize
                lines.append("  Total Memory: ~\(memSize) bytes")
            }

            if let path = sourcePath {
                lines.append("  Source: \(path)")
            } else {
                lines.append("  Source: created programmatically")
            }

            lines.append("  Valid indices: \(indices)")

            return lines.joined(separator: "\n")
        }

        /// Print debug information to console
        ///
        /// Example:
        /// ```swift
        /// table.printDebugInfo()
        /// ```
        func printDebugInfo() {
            print(debugInfo)
        }

        /// Validate table integrity
        ///
        /// - Returns: Array of validation issues (empty if valid)
        ///
        /// Example:
        /// ```swift
        /// let issues = table.validate()
        /// if issues.isEmpty {
        ///     print("Table is valid")
        /// } else {
        ///     print("Issues found:")
        ///     issues.forEach { print("  - \($0)") }
        /// }
        /// ```
        func validate() -> [String] {
            var issues: [String] = []

            // Check count
            if _count <= 0 {
                issues.append("Invalid count: \(_count)")
            }

            // Check if bitmaps are accessible
            var nullBitmapCount = 0
            for i in 0 ..< _count {
                if self[i] == nil {
                    nullBitmapCount += 1
                }
            }

            if nullBitmapCount > 0 {
                issues.append("\(nullBitmapCount) bitmaps are null/inaccessible")
            }

            // Check dimension consistency
            if !hasUniformDimensions {
                issues.append("Bitmaps have non-uniform dimensions")
            }

            // Check grid consistency
            if let cellsWide = _cellsWide, let rows = rows {
                let expectedCount = cellsWide * rows
                if _count > expectedCount {
                    issues.append("Count (\(_count)) exceeds grid capacity (\(expectedCount))")
                }
            }

            return issues
        }

        /// Export table information as dictionary
        ///
        /// Useful for logging and diagnostics.
        ///
        /// Example:
        /// ```swift
        /// let info = table.exportInfo()
        /// print(info)
        /// // ["count": 8, "width": 32, "height": 32, ...]
        /// ```
        func exportInfo() -> [String: Any] {
            var info: [String: Any] = [:]

            info["count"] = _count
            info["ownership"] = ownership == .owned ? "owned" : "borrowed"

            if let cellsWide = _cellsWide {
                info["cellsWide"] = cellsWide
            }

            if let rows = rows {
                info["rows"] = rows
            }

            if let width = _bitmapWidth {
                info["bitmapWidth"] = width
            }

            if let height = _bitmapHeight {
                info["bitmapHeight"] = height
            }

            if let path = sourcePath {
                info["sourcePath"] = path
            }

            info["memorySize"] = totalMemorySize
            info["isEmpty"] = isEmpty
            info["hasUniformDimensions"] = hasUniformDimensions

            return info
        }
    }
#endif

// MARK: - Result Extensions for Convenience

public extension Result where Success == BitmapTable, Failure == GraphicsError {
    /// Get table or crash with descriptive message (development only)
    ///
    /// ⚠️ Only use during prototyping - handle errors properly in production.
    ///
    /// Example:
    /// ```swift
    /// let table = BitmapTable.load("sprites").getOrCrash()
    /// // Crashes with error message if load fails
    /// ```
    func getOrCrash(file: String = #file, line: Int = #line) -> BitmapTable {
        switch self {
        case let .success(table):
            return table
        case let .failure(error):
            fatalError("BitmapTable operation failed: \(error) at \(file):\(line)")
        }
    }

    /// Get table or return nil (silent failure)
    ///
    /// Example:
    /// ```swift
    /// guard let table = BitmapTable.load("sprites").getOrNil() else {
    ///     return
    /// }
    /// ```
    func getOrNil() -> BitmapTable? {
        switch self {
        case let .success(table):
            return table
        case .failure:
            return nil
        }
    }
}

// MARK: - File Documentation Footer

/// # BitmapTable Usage Summary
///
/// ## Creation Methods
/// - `BitmapTable.create(count:width:height:)` - Create empty table
/// - `BitmapTable.load(path:)` - Load from file
/// - `BitmapTable(count:width:height:)` - Failable init
/// - `BitmapTable(path:)` - Failable init from file
///
/// ## Accessing Bitmaps
/// - `table[index]` - Unsafe subscript (nil on error)
/// - `table[safe: index]` - Safe subscript with Result
/// - `table.getBitmap(at:)` - Explicit Result-based access
/// - `table.forEachBitmap { bitmap, index in }` - Iteration
///
/// ## Properties
/// - `table.count` - Total bitmaps
/// - `table.cellsWide` - Grid width
/// - `table.rows` - Grid height
/// - `table.bitmapSize` - Individual bitmap dimensions
/// - `table.path` - Original file path
///
/// ## Animation Support
/// - `table.nextFrame(after:)` - Sequential frame access
/// - `table.frameAtTime(_:fps:loop:)` - Time-based frames
/// - `table.animationSequence(startFrame:frameCount:loop:)` - Sequence helper
///
/// ## Grid Operations
/// - `table.bitmapAt(column:row:)` - Grid position access
/// - `table.gridPosition(for:)` - Index to grid conversion
/// - `table.drawGrid(at:spacing:)` - Render entire grid
///
/// ## Important Lifecycle Notes
///
/// ⚠️ **BORROWED BITMAPS**: All bitmaps from subscript/getBitmap are borrowed.
/// They become invalid when the table is deallocated.
///
/// ✅ **SAFE**: Use bitmaps within table's scope or copy them
/// ❌ **UNSAFE**: Store bitmap references beyond table lifetime
///
/// ## Performance Tips
/// - Use `table[index]` for fast access in hot paths
/// - Use `table[safe: index]` when debugging
/// - Cache table reference to keep bitmaps valid
/// - Copy bitmaps only when necessary (memory cost)
