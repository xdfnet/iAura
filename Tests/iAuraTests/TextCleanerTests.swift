import XCTest
@testable import iAuraKit

final class TextCleanerTests: XCTestCase {

    func testRemovesSpeechNoise() {
        let input = """
        ## 结果
        - **验证通过**：[main.go](/Users/testuser/projects/ivox/main.go:123)
        - commit: a97e57d12345 Improve latest-only task handling
        - 路径：/Users/testuser/projects/ivox/main.go
        https://example.com/path
        飞哥，需要你重启服务。
        """
        let got = cleanText(input)
        let badWords = ["**", "`", "/Users/testuser", "https://", "a97e57d12345"]
        for bad in badWords {
            XCTAssertFalse(got.contains(bad), "should not contain '\(bad)'")
        }
        let goodWords = ["结果", "验证通过", "main.go", "路径", "飞哥，需要你重启服务。"]
        for good in goodWords {
            XCTAssertTrue(got.contains(good), "should contain '\(good)'")
        }
    }

    func testPreservesLinkTitleBeforeRemovingURL() {
        let got = cleanText("参考：[架构文档](https://example.com/docs)。")
        XCTAssertTrue(got.contains("架构文档"))
        XCTAssertFalse(got.contains("https://"))
    }

    func testRemovesUUIDBeforeCommitHash() {
        let got = cleanText("请求 ID：123e4567-e89b-12d3-a456-426614174000，状态成功。")
        XCTAssertFalse(got.contains("123e4567"))
        XCTAssertTrue(got.contains("状态成功。"))
    }

    func testKeepsChinesePercentConclusion() {
        let input = "下载 42% 12MB/s eta 1m\n测试通过率 95%，可以发布。"
        let got = cleanText(input)
        XCTAssertFalse(got.contains("12MB/s"))
        XCTAssertTrue(got.contains("测试通过率 95%，可以发布。"))
    }

    func testKeepsPlainPercentLine() {
        let got = cleanText("覆盖率 95%")
        XCTAssertTrue(got.contains("覆盖率 95%"))
    }

    func testKeepsOrdinaryFileReferenceLine() {
        let got = cleanText("已更新 main.go 和 README.md。")
        XCTAssertTrue(got.contains("main.go"))
        XCTAssertTrue(got.contains("README.md"))
    }
}
