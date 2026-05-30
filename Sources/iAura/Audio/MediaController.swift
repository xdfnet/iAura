import Foundation

struct MediaController {
    private static let baseURL = "http://127.0.0.1:8888"

    func pause() {
        Log.info("媒体控制: 暂停")
        send("/api/pause")
    }

    func resume() {
        Log.info("媒体控制: 恢复")
        send("/api/play")
    }

    private func send(_ path: String) {
        guard let url = URL(string: Self.baseURL + path) else { return }
        var request = URLRequest(url: url)
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
