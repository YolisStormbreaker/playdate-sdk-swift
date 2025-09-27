import CPlaydate

var localGraphicsAPI: playdate_graphics { playdateAPI.graphics.unsafelyUnwrapped.pointee }

/// Access the Playdate graphics system.
public enum GraphicsLegacy {}

public extension LCDSolidColor {
    var asLCDColor: LCDColor {
        return LCDColor(self.rawValue)
    }
}

extension GraphicsLegacy {
  /// Pushes a new drawing context for drawing into the given bitmap.
  ///
  /// If target is nil, the drawing functions will use the display framebuffer.
  public static func pushContext(target: OpaquePointer?) {
    localGraphicsAPI.pushContext.unsafelyUnwrapped(target)
  }

  /// Pops a context off the stack (if any are left), restoring the
  /// drawing settings from before the context was pushed.
  public static func popContext() {
    localGraphicsAPI.popContext.unsafelyUnwrapped()
  }

  /// Sets the stencil used for drawing.
  ///
  /// For a tiled stencil, use ``setStencilImage(stencil:tile:)`` instead.
  public static func setStencil(stencil: OpaquePointer?) {
    localGraphicsAPI.setStencil.unsafelyUnwrapped(stencil)
  }

  /// Sets the stencil used for drawing.
  ///
  /// If the tile flag is set the stencil image will be tiled. Tiled
  /// stencils must have width equal to a multiple of 32 pixels.
  public static func setStencilImage(stencil: OpaquePointer?, tile: Int32) {
    localGraphicsAPI.setStencilImage.unsafelyUnwrapped(stencil, tile)
  }

  /// Sets the mode used for drawing bitmaps.
  ///
  /// Note that text drawing uses bitmaps, so this affects how fonts are
  /// displayed as well.
  public static func setDrawMode(mode: LCDBitmapDrawMode) {
    localGraphicsAPI.setDrawMode.unsafelyUnwrapped(mode)
  }

  /// Sets the current clip rect, using world coordinates.
  ///
  /// The given rectangle will be translated by the current drawing offset.
  /// The clip rect is cleared at the beginning of each update.
  public static func setClipRect(x: Int32, y: Int32, width: Int32, height: Int32) {
    localGraphicsAPI.setClipRect.unsafelyUnwrapped(x, y, width, height)
  }

  /// Sets the current clip rect in screen coordinates.
  public static func setScreenClipRect(x: Int32, y: Int32, width: Int32, height: Int32) {
    localGraphicsAPI.setScreenClipRect.unsafelyUnwrapped(x, y, width, height)
  }

  /// Clears the current clip rect.
  public static func clearClipRect() {
    localGraphicsAPI.clearClipRect.unsafelyUnwrapped()
  }

  /// Sets the end cap style used in the line drawing functions.
  public static func setLineCapStyle(endCapStyle: LCDLineCapStyle) {
    localGraphicsAPI.setLineCapStyle.unsafelyUnwrapped(endCapStyle)
  }
}

// MARK: - Bitmaps
extension GraphicsLegacy {
  /// Clears bitmap, filling with the given bgcolor.
  public static func clearBitmap(bitmap: OpaquePointer, bgcolor: LCDColor) {
    localGraphicsAPI.clearBitmap.unsafelyUnwrapped(bitmap, bgcolor)
  }

  /// Returns a new LCDBitmap that is an exact copy of bitmap.
  public static func copyBitmap(bitmap: OpaquePointer) -> OpaquePointer? {
    localGraphicsAPI.copyBitmap.unsafelyUnwrapped(bitmap)
  }

  /// Returns 1 if any of the opaque pixels in bitmap1 when positioned at x1, y1 with flip1 overlap any of the opaque pixels in bitmap2 at x2, y2 with flip2 within the non-empty rect, or 0 if no pixels overlap or if one or both fall completely outside of rect.
  public static func checkMaskCollision(
    bitmap1: OpaquePointer, x1: Int32, y1: Int32, flip1: LCDBitmapFlip,
    bitmap2: OpaquePointer, x2: Int32, y2: Int32, flip2: LCDBitmapFlip,
    rect: LCDRect
  ) -> Int32 {
    localGraphicsAPI.checkMaskCollision.unsafelyUnwrapped(bitmap1, x1, y1, flip1, bitmap2, x2, y2, flip2, rect)
  }

  /// Draws the bitmap with its upper-left corner at location x, y, using the given flip orientation.
  public static func drawBitmap(bitmap: OpaquePointer, x: Int32, y: Int32, flip: LCDBitmapFlip) {
    localGraphicsAPI.drawBitmap.unsafelyUnwrapped(bitmap, x, y, flip)
  }

  /// Draws the bitmap scaled to xscale and yscale with its upper-left corner at location x, y. Note that flip is not available when drawing scaled bitmaps but negative scale values will achieve the same effect.
  public static func drawScaledBitmap(bitmap: OpaquePointer, x: Int32, y: Int32, xscale: Float, yscale: Float) {
    localGraphicsAPI.drawScaledBitmap.unsafelyUnwrapped(bitmap, x, y, xscale, yscale)
  }

  /// Draws the bitmap scaled to xscale and yscale then rotated by degrees with its center as given by proportions centerx and centery at x, y.
  public static func drawRotatedBitmap(
    bitmap: OpaquePointer, x: Int32, y: Int32, degrees: Float,
    centerx: Float, centery: Float, xscale: Float, yscale: Float
  ) {
    localGraphicsAPI.drawRotatedBitmap.unsafelyUnwrapped(bitmap, x, y, degrees, centerx, centery, xscale, yscale)
  }

  /// Frees the given bitmap.
  public static func freeBitmap(bitmap: OpaquePointer) {
    localGraphicsAPI.freeBitmap.unsafelyUnwrapped(bitmap)
  }

  /// Gets various info about bitmap including its width and height and raw pixel data. The data is 1 bit per pixel packed format, in MSB order.
  public static func getBitmapData(
    bitmap: OpaquePointer, width: UnsafeMutablePointer<Int32>,
    height: UnsafeMutablePointer<Int32>?, rowbytes: UnsafeMutablePointer<Int32>?,
    mask: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
    data: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?
  ) {
    localGraphicsAPI.getBitmapData.unsafelyUnwrapped(bitmap, width, height, rowbytes, mask, data)
  }

  /// Allocates and returns a new LCDBitmap from the file at path. If there is no file at path, the function returns null.
  public static func loadBitmap(path: StaticString) -> OpaquePointer {
    let result = localGraphicsAPI.loadBitmap(path.utf8Start, nil)
    guard let result = result else { fatalError() }
    return result
  }

  /// Loads the image at path into the previously allocated bitmap.
  public static func loadIntoBitmap(path: StaticString, bitmap: OpaquePointer) {
    localGraphicsAPI.loadIntoBitmap(path.utf8Start, bitmap, nil)
  }

  /// Allocates and returns a new width by height LCDBitmap filled with bgcolor.
  public static func newBitmap(width: Int32, height: Int32, bgcolor: LCDColor) -> OpaquePointer? {
    localGraphicsAPI.newBitmap.unsafelyUnwrapped(width, height, bgcolor)
  }

  /// Draws the bitmap with its upper-left corner at location x, y tiled inside a width by height rectangle.
  public static func tileBitmap(bitmap: OpaquePointer, x: Int32, y: Int32, width: Int32, height: Int32, flip: LCDBitmapFlip) {
    localGraphicsAPI.tileBitmap.unsafelyUnwrapped(bitmap, x, y, width, height, flip)
  }

  /// Returns a new, rotated and scaled LCDBitmap based on the given bitmap.
  public static func rotatedBitmap(bitmap: OpaquePointer, rotation: Float, xscale: Float, yscale: Float) -> (OpaquePointer?, Int32) {
    var allocatedSize: Int32 = 0
    let result = localGraphicsAPI.rotatedBitmap.unsafelyUnwrapped(bitmap, rotation, xscale, yscale, &allocatedSize)
    return (result, allocatedSize)
  }

  /// Sets a mask image for the given bitmap. The set mask must be the same size as the target bitmap.
  public static func setBitmapMask(bitmap: OpaquePointer, mask: OpaquePointer) -> Int32 {
    localGraphicsAPI.setBitmapMask.unsafelyUnwrapped(bitmap, mask)
  }

  /// Gets a mask image for the given bitmap. If the image doesn’t have a mask, getBitmapMask returns NULL.
  public static func getBitmapMask(bitmap: OpaquePointer) -> OpaquePointer? {
    localGraphicsAPI.getBitmapMask.unsafelyUnwrapped(bitmap)
  }
}

// MARK: - Geometry
extension GraphicsLegacy {
  /// Draws an ellipse inside the rectangle {x, y, width, height} of width lineWidth (inset from the rectangle bounds). If `startAngle != _endAngle`, this draws an arc between the given angles. Angles are given in degrees, clockwise from due north.
  public static func drawEllipse(x: Int32, y: Int32, width: Int32, height: Int32, lineWidth: Int32, startAngle: Float, endAngle: Float, color: LCDColor) {
    localGraphicsAPI.drawEllipse.unsafelyUnwrapped(x, y, width, height, lineWidth, startAngle, endAngle, color)
  }

  /// Fills an ellipse inside the rectangle {x, y, width, height}. If `startAngle != _endAngle`, this draws a wedge/Pacman between the given angles. Angles are given in degrees, clockwise from due north.
  public static func fillEllipse(x: Int32, y: Int32, width: Int32, height: Int32, startAngle: Float, endAngle: Float, color: LCDColor) {
    localGraphicsAPI.fillEllipse.unsafelyUnwrapped(x, y, width, height, startAngle, endAngle, color)
  }

  /// Draws a line from x1, y1 to x2, y2 with a stroke width of width.
  public static func drawLine(x1: Int32, y1: Int32, x2: Int32, y2: Int32, width: Int32, color: LCDColor) {
    localGraphicsAPI.drawLine.unsafelyUnwrapped(x1, y1, x2, y2, width, color)
  }

  /// Draws a width by height rect at x, y.
  public static func drawRect(x: Int32, y: Int32, width: Int32, height: Int32, color: LCDColor) {
    localGraphicsAPI.drawRect.unsafelyUnwrapped(x, y, width, height, color)
  }

  /// Draws a filled width by height rect at x, y.
  public static func fillRect(x: Int32, y: Int32, width: Int32, height: Int32, color: LCDColor) {
    localGraphicsAPI.fillRect.unsafelyUnwrapped(x, y, width, height, color)
  }

  /// Draws a filled triangle with points at x1, y1, x2, y2, and x3, y3.
  public static func fillTriangle(x1: Int32, y1: Int32, x2: Int32, y2: Int32, x3: Int32, y3: Int32, color: LCDColor) {
    localGraphicsAPI.fillTriangle.unsafelyUnwrapped(x1, y1, x2, y2, x3, y3, color)
  }

  /// Fills the polygon with vertices at the given coordinates using the given color and fill, or winding, rule.
  public static func fillPolygon(nPoints: Int32, points: UnsafeMutablePointer<Int32>?, color: LCDColor, fillRule: LCDPolygonFillRule) {
    localGraphicsAPI.fillPolygon.unsafelyUnwrapped(nPoints, points, color, fillRule)
  }
}

// MARK: - Text
extension GraphicsLegacy {
  /// Draws the given text using the provided options. 
  /// If no font has been set with setFont, the default system font Asheville Sans 14 Light is used.
  /// Returns the width of the drawn text.
  public static func drawText(
      _ text: String, 
      encoding: PDStringEncoding, 
      x: Int32, 
      y: Int32
  ) -> Int32 {
      return text.withCString(encodedAs: UTF8.self) { textPtr in
          let length = text.utf8.count
          return localGraphicsAPI.drawText.unsafelyUnwrapped(
              textPtr,           // const void* text
              length,            // size_t len 
              encoding,          // PDStringEncoding encoding
              x,                 // int x
              y                  // int y
          )
      }
  }
  
  //// Draws the text in the given rectangle using the provided options.
  /// If no font has been set with setFont, the default system font Asheville Sans 14 Light is used.
  /// This function does not return a value.
  public static func drawTextInRect(
      _ text: String,
      encoding: PDStringEncoding,
      x: Int32,
      y: Int32, 
      width: Int32,
      height: Int32,
      wrap: PDTextWrappingMode,
      align: PDTextAlignment
  ) {
      text.withCString(encodedAs: UTF8.self) { textPtr in
          let length = text.utf8.count
          localGraphicsAPI.drawTextInRect.unsafelyUnwrapped(
              textPtr,           // const void* text
              length,            // size_t len
              encoding,          // PDStringEncoding encoding  
              x,                 // int x
              y,                 // int y
              width,             // int width
              height,            // int height
              wrap,              // PDTextWrappingMode wrap
              align              // PDTextAlignment align
          )
      }
  }

  /// Draws text with UTF-8 encoding (convenience method)
  public static func drawText(_ text: String, x: Int32, y: Int32) -> Int32 {
      return drawText(text, encoding: PDStringEncoding.kUTF8Encoding, x: x, y: y)
  }
  
  /// Draws text in rectangle with UTF-8 encoding (convenience method)  
  public static func drawTextInRect(
      _ text: String,
      x: Int32, y: Int32, width: Int32, height: Int32,
      wrap: PDTextWrappingMode = PDTextWrappingMode.wrapWord,
      align: PDTextAlignment = PDTextAlignment.alignTextLeft
  ) {
      drawTextInRect(
          text, 
          encoding: PDStringEncoding.kUTF8Encoding, 
          x: x, y: y, width: width, height: height,
          wrap: wrap, 
          align: align
      )
  }
  
  /// Sets the tracking to use when drawing text.
  public static func setTextTracking(tracking: Int32) {
    localGraphicsAPI.setTextTracking.unsafelyUnwrapped(tracking)
  }
  
  /// Gets the tracking used when drawing text.
  public static func getTextTracking() -> Int32 {
    localGraphicsAPI.getTextTracking.unsafelyUnwrapped()
  }
  
  /// Sets the leading adjustment (added to the leading specified in the font) to use when drawing text.
  public static func setTextLeading(leading: Int32) {
    localGraphicsAPI.setTextLeading.unsafelyUnwrapped(leading)
  }
}

public typealias LCDFont = OpaquePointer

// MARK: - Font
extension GraphicsLegacy {
  
  public enum FontError: Error {
      case fileNotFound(String)
      case invalidFormat(String)
      case loadFailed(String)
      
      var localizedDescription: String {
          switch self {
          case .fileNotFound(let message):
              return "Font not found: \(message)"
          case .invalidFormat(let message):
              return "Wrong font's format: \(message)"
          case .loadFailed(let message):
              return "Can't load font: \(message)"
          }
      }
  }
  
  /// Returns the LCDFont object for the font file at path.
  /// In case of error, returns an error string describing the issue.
  /// The returned font can be freed with system realloc when no longer in use.
  ///
  /// - Parameter path: Path to the font file (e.g., "/System/Fonts/Asheville-Sans-14-Bold.pft")
  /// - Returns: Result containing either the loaded font or error description
  ///
  /// Example usage:
  /// ```swift
  /// let result = loadFont(path: "/System/Fonts/Asheville-Sans-14-Bold.pft")
  /// switch result {
  /// case .success(let font):
  ///     print("Font loaded successfully")
  /// case .failure(let error):
  ///     print("Failed to load font: \(error)")
  /// }
  /// ```
  ///
  /// - SeeAlso: [Official Documentation](https://sdk.play.date/inside-playdate-with-c/#f-graphics.loadFont)
  public static func loadFont(path: String) -> Result<LCDFont, FontError> {
      return path.withCString { pathPtr in
          var errorPtr: UnsafePointer<CChar>? = nil
          
          let font = localGraphicsAPI.loadFont.unsafelyUnwrapped(pathPtr, &errorPtr)
          
          if let font = font {
              return .success(font)
          } else {
              let errorMessage: FontError
              if let errorPtr = errorPtr {
                  errorMessage = FontError.fileNotFound(String(cString: errorPtr))
              } else {
                  errorMessage = FontError.loadFailed("Unknown error occurred while loading font")
              }
              return .failure(errorMessage)
          }
      }
  }
  
  /// Sets the font to use in subsequent drawText calls.
  /// 
  /// This function establishes which font will be used for all text drawing operations
  /// until a different font is set or the default font is restored.
  ///
  /// - Parameter font: The LCDFont pointer obtained from loadFont() function
  ///
  /// Example usage:
  /// ```swift
  /// let result = loadFont(path: "/System/Fonts/Asheville-Sans-14-Bold.pft")
  /// switch result {
  /// case .success(let font):
  ///     setFont(font)
  ///     
  ///     let width = drawText("Hello, World!", x: 10, y: 20)
  ///     drawTextInRect("Long text...", x: 0, y: 40, width: 200, height: 100)
  ///     
  /// case .failure(let error):
  ///     print("Failed to load font: \(error)")
  /// }
  /// ```
  ///
  /// - Note: Equivalent to `playdate.graphics.setFont()` in the Lua API
  /// - SeeAlso: [Official Documentation](https://sdk.play.date/inside-playdate-with-c/#f-graphics.setFont)
  public static func setFont(_ font: LCDFont) {
      localGraphicsAPI.setFont.unsafelyUnwrapped(font)
  }

}

// MARK: - Drawing
extension GraphicsLegacy {
  /// Clears the entire display, filling it with the specified color.
  /// 
  /// This function fills the complete screen with a solid color, effectively
  /// erasing all previously drawn content.
  ///
  /// - Parameter color: The color to fill the screen with (LCDColor type)
  ///
  /// Example usage:
  /// ```swift
  /// // Clear screen with black color
  /// GraphicsLegacy.clear(color: LCDSolidColor.kColorBlack.rawValue)
  /// 
  /// // Clear screen with white color  
  /// GraphicsLegacy.clear(color: LCDSolidColor.kColorWhite.rawValue)
  /// ```
  ///
  /// - Note: Equivalent to `playdate.graphics.clear()` in the Lua API
  /// - SeeAlso: [Official Documentation](https://sdk.play.date/inside-playdate-with-c/#f-graphics.clear)
  public static func clear(color: LCDColor) {
      localGraphicsAPI.clear.unsafelyUnwrapped(color)
  }
}

// MARK: - Miscellaneous
extension GraphicsLegacy {
  /// Returns the current display frame buffer. Rows are 32-bit aligned, so the
  /// row stride is 52 bytes, with the extra 2 bytes per row ignored. Bytes are
  /// MSB-ordered; i.e., the pixel in column 0 is the 0x80 bit of the first byte
  /// of the row.
  public static func getFrame() -> UnsafeMutablePointer<UInt8>? {
    localGraphicsAPI.getFrame.unsafelyUnwrapped()
  }

  /// Returns the raw bits in the display buffer, the last completed frame.
  public static func getDisplayFrame() -> UnsafeMutablePointer<UInt8>? {
    localGraphicsAPI.getDisplayFrame.unsafelyUnwrapped()
  }

  /// After updating pixels in the buffer returned by getFrame(), you must tell
  /// the graphics system which rows were updated. This function marks a
  /// contiguous range of rows as updated (e.g., `markUpdatedRows(0,LCD_ROWS-1`)
  /// tells the system to update the entire display). Both “start” and “end” are
  /// included in the range.
  public static func markUpdatedRows(start: Int32, end: Int32) {
    localGraphicsAPI.markUpdatedRows.unsafelyUnwrapped(start, end)
  }
}
