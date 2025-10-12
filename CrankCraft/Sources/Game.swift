import Playdate

struct Game {
    private var x: Int32 = 0
    private var y: Int32 = 0
    private var dx: Int32 = 1
    private var dy: Int32 = 2
    private var degrees: Float = 0.0

    private let iconBitmap: Bitmap?
    // let currentFont: Font
    var currentFontIndex: Int = 0

    private let systemFontsRaw: [SystemFont] = [
        SystemFont.ashevilleSans14Bold,
        SystemFont.ashevilleSans14LightOblique,
        SystemFont.ashevilleSans14Light,
        SystemFont.ashevilleSans24Light,
        SystemFont.roobert10Bold,
        SystemFont.roobert11Bold,
        SystemFont.roobert11Medium,
        SystemFont.roobert20Medium,
        SystemFont.roobert24Medium,
    ]

    private var systemFonts = [Font]()

    init() {
        // Setup the device before any other operations.
        srand(System.getSecondsSinceEpoch(milliseconds: nil))
        Display.setRefreshRate(rate: 0)

        Graphics.setDefaultFont()

        // let loadedFont: Font

        iconBitmap = Bitmap.load(path: "assets/images/launcher/icon.png").orNil

        for systemFont in systemFontsRaw {
            Font.load(path: systemFont.path).onSuccess { font in
                systemFonts.append(font)
            }
        }

        // switch Font.load(path: SystemFont.roobert20Medium.path) {
        // case let .success(font):
        //     loadedFont = font
        //     font.setAsCurrent()
        // case let .failure(error):
        //     loadedFont = Font.systemFont()
        //     Graphics.setDefaultFont()
        //     Graphics.drawText("Failed to load font: \(error.description)", at: Point(x: 10, y: 10))
        // }
        // currentFont = loadedFont
    }

    private mutating func getNextFont() -> Font {
        if currentFontIndex + 1 >= systemFonts.count {
            currentFontIndex = 0
        } else {
            currentFontIndex += 1
        }
        return systemFonts[currentFontIndex]
    }

    mutating func updateGame() {
        let TEXT_WIDTH: Int32 = 86
        let TEXT_HEIGHT: Int32 = 16

        GraphicsLegacy.clear(color: LCDSolidColor.colorWhite.asLCDColor)

        iconBitmap?.drawRotatedCenteredOnScreen(
            degrees: degrees
        )

        _ = Graphics.drawText(
            "Hello World!",
            at: Point(x: x, y: y),
            encoding: StringEncoding.utf8,
        )

        Graphics.drawText("Current Font: \(systemFontsRaw[currentFontIndex].displayName)", at: Point(x: 0, y: 10))

        x += dx
        y += dy

        if x < 0 || x > LCD_COLUMNS - TEXT_WIDTH {
            dx = -dx
            getNextFont().setAsCurrent()
        }

        if y < 0 || y > LCD_ROWS - TEXT_HEIGHT {
            dy = -dy
            getNextFont().setAsCurrent()
        }

        if degrees >= 359.0 {
            degrees = 0.0
        } else {
            degrees += 1.0
        }

        System.drawFPS(x: 0, y: 0)
    }
}
