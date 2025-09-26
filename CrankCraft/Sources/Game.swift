import Playdate

struct Game {
  init() {
    // Setup the device before any other operations.
    srand(System.getSecondsSinceEpoch(milliseconds: nil))
    Display.setRefreshRate(rate: 50)
  }

  mutating func updateGame() {
    Graphics.drawTextInRect(
        "Hello World!",
        encoding: PDStringEncoding.kUTF8Encoding,
        x: Display.width/4, 
        y: Display.height/4,
        width: Display.width/2, 
        height: Display.height/2,
        wrap: PDTextWrappingMode.wrapWord,
        align: PDTextAlignment.alignTextCenter
    )
  }
}
