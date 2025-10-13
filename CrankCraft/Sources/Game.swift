import Playdate

struct Game {
    private var x: Int32 = 0
    private var y: Int32 = 0
    private var dx: Int32 = 1
    private var dy: Int32 = 2
    private var degrees: Float = 0.0

    private let iconBitmap: Bitmap?
    // private let currentFont: Font
    private var currentFontIndex: Int = 0

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

        let loadedFont: Font

        iconBitmap = Bitmap.load(path: "assets/images/launcher/icon.png").orNil

        for systemFont in systemFontsRaw {
            Font.load(path: systemFont.path).onSuccess { font in
                systemFonts.append(font)
            }
        }

        // switch Font.load(path: "assets/fonts/Roboto-Regular-20.pft") {
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
        GraphicsLegacy.clear(color: LCDSolidColor.colorWhite.asLCDColor)

        iconBitmap?.drawRotatedCenteredOnScreen(
            degrees: degrees
        )

        let currentSystemFont = systemFonts[currentFontIndex]
        let bouncingText = "Hello World!"
        let textWidth: Int32 = Font.systemFont().getTextWidth(bouncingText)
        let textHeight: Int32 = Font.systemFont().getTextHeight(bouncingText, forMaxWidth: textWidth)

        _ = Graphics.drawText(
            bouncingText,
            at: Point(x: x, y: y),
            encoding: StringEncoding.utf8,
        )

        Graphics.setDefaultFont()
        Graphics.drawText("Current Font: \(systemFontsRaw[currentFontIndex].displayName)", at: Point(x: 0, y: 10))
        currentSystemFont.setAsCurrent()

        x += dx
        y += dy

        if x < 0 || x > LCD_COLUMNS - textWidth {
            dx = -dx
            getNextFont().setAsCurrent()
        }

        if y < 0 || y > LCD_ROWS - textHeight {
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
