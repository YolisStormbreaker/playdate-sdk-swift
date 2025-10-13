// Ring buffer for frames
/* WIP
 class FrameBuffer {
     private var frames: [VideoFrame] = []
     private var capacity: Int
     private var readIndex: Int = 0
     private var writeIndex: Int = 0

     var count: Int {
         return frames.count
     }

     var isFull: Bool {
         return count >= capacity
     }

     func push(_ frame: VideoFrame) {
         guard !isFull else { return }
         frames.append(frame)
     }

     func pop() -> VideoFrame? {
         guard !frames.isEmpty else { return nil }
         return frames.removeFirst()
     }

     func clear() {
         frames.removeAll()
         readIndex = 0
         writeIndex = 0
     }
 }
 */
