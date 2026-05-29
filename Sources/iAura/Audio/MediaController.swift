import AppKit
import CoreGraphics
import Foundation

struct MediaController {
    /// 发送媒体键（播放/暂停切换）
    func pause() {
        Log.info("媒体控制: 暂停")
        sendMediaKey()
    }

    func resume() {
        Log.info("媒体控制: 恢复")
        sendMediaKey()
    }

    private func sendMediaKey() {
        let key: Int32 = 16  // NX_KEYTYPE_PLAY

        func post(data1: Int) {
            guard let nsEvent = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) else { return }
            nsEvent.cgEvent?.post(tap: .cghidEventTap)
        }

        post(data1: Int((key << 16) | (0xA << 8)))  // down
        usleep(100_000)
        post(data1: Int((key << 16) | (0xB << 8)))  // up
    }
}
