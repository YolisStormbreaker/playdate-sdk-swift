import Playdate

class VideoPlayerGame {
    private var x: Int32 = 0
    private var y: Int32 = 0
    private var dx: Int32 = 1
    private var dy: Int32 = 2

    private var player: VideoPlayer?

    private var restartFlag: Bool = false

    init() {
        // Setup the device before any other operations.
        srand(System.getSecondsSinceEpoch(milliseconds: nil))
        Display.setRefreshRate(rate: 0)

        Graphics.setDefaultFont()

        player = VideoPlayer(path: "assets/videos/family_walking_lite.pdv")
        player?.showDebugOverlay = true

        player?.onVideoEnd = {
            self.restartFlag = true
        }
    }

    func updateGame() {
        _ = player?.updateAndRender()

        if restartFlag {
            restartFlag = false
            player?.restart()
        }

        if System.buttonState.pushed == .a {
            player?.restart()
        }

        if System.buttonState.pushed == .b {
            player = VideoPlayer(path: "assets/videos/rick_roll.pdv")
            player?.showDebugOverlay = false
            player?.onVideoEnd = {
                self.restartFlag = true
            }
        }
        System.drawFPS(x: 0, y: 0)
    }
}
