import Playdate

struct Game {
  
  let fontPath = "/System/Fonts/Asheville-Sans-14-Bold.pft"
  var font: LCDFont? = nil
  
  private var x: Int32 = 0
  private var y: Int32 = 0
  private var dx: Int32 = 1
  private var dy: Int32 = 2
  
  init() {
    // Setup the device before any other operations.
    srand(System.getSecondsSinceEpoch(milliseconds: nil))
    Display.setRefreshRate(rate: 0)
    if (font == nil) {
      let result = GraphicsLegacy.loadFont(path: fontPath)
      switch result {
        case .success(let font):
            GraphicsLegacy.setFont(font)
        case .failure(let error):
            GraphicsLegacy.drawText("Failed to load font: \(error)", x: 10, y: 10)
        }
    }
  }

  mutating func updateGame() {
    
    let TEXT_WIDTH: Int32 = 86
    let TEXT_HEIGHT: Int32 = 16
    
    GraphicsLegacy.clear(color: LCDSolidColor.colorWhite.asLCDColor)
    let _ = GraphicsLegacy.drawText(
        "Hello World!",
        encoding: PDStringEncoding.kUTF8Encoding,
        x: x, 
        y: y,
    )
    
    x += dx
    y += dy
    
    if x < 0 || x > LCD_COLUMNS - TEXT_WIDTH {
        dx = -dx
    }
    
    if y < 0 || y > LCD_ROWS - TEXT_HEIGHT {
        dy = -dy
    }

    System.drawFPS(x: 0, y: 0)

  }
}
