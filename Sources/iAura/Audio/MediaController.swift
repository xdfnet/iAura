import Foundation

struct MediaController {
    private static let apiURL = URL(string: "http://127.0.0.1:8888/api/space")!

    func pause() {
        Log.info("媒体控制: 暂停")
        sendToggle()
    }

    func resume() {
        Log.info("媒体控制: 恢复")
        sendToggle()
    }

    private func sendToggle() {
        var request = URLRequest(url: Self.apiURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 2
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                Log.error("媒体控制请求失败: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                Log.error("媒体控制返回非 200: \(http.statusCode)")
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
    }
}
