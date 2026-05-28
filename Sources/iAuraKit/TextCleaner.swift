import Foundation

// MARK: - 正则缓存 (编译一次)

private let markdownLinkRe = try! NSRegularExpression(pattern: #"\[[^\]]+\]\(([^)]*)\)"#)
private let absolutePathRe = try! NSRegularExpression(pattern: #"/(?:Users|private|tmp|var|opt|usr|bin|sbin|etc|Library|Applications)/\S+"#)
private let commitHashRe = try! NSRegularExpression(pattern: #"\b[0-9a-f]{12,40}\b"#)
private let uuidRe = try! NSRegularExpression(pattern: #"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b"#)
private let urlRe = try! NSRegularExpression(pattern: #"https?://\S+"#)
private let ansiEscapeRe = try! NSRegularExpression(pattern: #"\x1b\[[0-9;]*[A-Za-z]"#)
private let markdownListRe = try! NSRegularExpression(pattern: #"^\s*(?:[-*+]\s+|\d+[.)]\s+)"#)
private let htmlTagRe = try! NSRegularExpression(pattern: #"<[^>]+>"#)
private let codeFenceRe = try! NSRegularExpression(pattern: "^```")
private let artifactStartRe = try! NSRegularExpression(pattern: #"(?i)^<artifact\b"#)
private let htmlDocumentLineRe = try! NSRegularExpression(pattern: #"(?i)^<!doctype html|^<html\b|^<head\b|^<body\b|^<style\b|^</"#)
private let speedNoiseRe = try! NSRegularExpression(pattern: #"(?i)\d+(?:\.\d+)?\s*(?:kb|mb|gb)/s"#)
private let etaNoiseRe = try! NSRegularExpression(pattern: #"(?i)\bETA\b|预计剩余|剩余时间"#)
private let multiSpaceRe = try! NSRegularExpression(pattern: #"\s+"#)

// MARK: - 公开 API

public func cleanText(_ text: String) -> String {
    let rawLines = text.components(separatedBy: "\n")
    var lines: [String] = []
    var inCodeBlock = false
    var inArtifact = false
    var inMarkdownTable = false

    for i in 0..<rawLines.count {
        let line = rawLines[i].trimmingCharacters(in: .whitespaces)
        if line.isEmpty { inMarkdownTable = false; continue }

        if codeFenceRe.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil {
            inCodeBlock.toggle(); continue
        }
        if inCodeBlock { continue }

        if artifactStartRe.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil {
            if !line.lowercased().contains("</artifact>") { inArtifact = true }; continue
        }
        if inArtifact {
            if line.lowercased().contains("</artifact>") { inArtifact = false }; continue
        }

        if isMarkdownTableSeparator(line) {
            if !lines.isEmpty, i > 0, isMarkdownTableRow(rawLines[i - 1]) { lines.removeLast() }
            inMarkdownTable = true; continue
        }
        if inMarkdownTable {
            if isMarkdownTableRow(line) { continue }
            inMarkdownTable = false
        }

        if shouldSkipSpeechLine(line) { continue }

        let cleaned = cleanSpeechLine(line)
        if !cleaned.isEmpty { lines.append(cleaned) }
    }
    return lines.joined(separator: "，")
}

// MARK: - 内部

private func shouldSkipSpeechLine(_ line: String) -> Bool {
    if line.hasPrefix("---") && line.filter({ $0 == "-" }).count > 3 { return true }
    if htmlDocumentLineRe.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil { return true }
    if isProgressNoiseLine(line) { return true }
    if isMostlyTableRow(line) { return true }
    return false
}

private func isMarkdownTableSeparator(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    return trimmed.contains("|") && trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "|-: ")).isEmpty
}

private func isMarkdownTableRow(_ line: String) -> Bool {
    line.trimmingCharacters(in: .whitespaces).filter({ $0 == "|" }).count >= 2
}

private func cleanSpeechLine(_ line: String) -> String {
    var s = line
    let range = NSRange(location: 0, length: s.utf16.count)

    s = ansiEscapeRe.stringByReplacingMatches(in: s, range: range, withTemplate: "")
    s = markdownListRe.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: s.utf16.count), withTemplate: "")

    // Markdown 链接: 保留标题 [title](url) → title
    let linkMatches = markdownLinkRe.matches(in: s, range: NSRange(location: 0, length: s.utf16.count)).reversed()
    for match in linkMatches {
        let full = (s as NSString).substring(with: match.range)
        if let end = full.firstIndex(of: "]") {
            let title = String(full[full.index(after: full.startIndex)..<end])
            let startIdx = s.index(s.startIndex, offsetBy: match.range.location)
            let endIdx = s.index(startIdx, offsetBy: match.range.length)
            s.replaceSubrange(startIdx..<endIdx, with: title)
        }
    }

    s = urlRe.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: s.utf16.count), withTemplate: "")
    s = absolutePathRe.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: s.utf16.count), withTemplate: " 路径 ")
    s = uuidRe.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: s.utf16.count), withTemplate: "")
    s = commitHashRe.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: s.utf16.count), withTemplate: "")
    s = htmlTagRe.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: s.utf16.count), withTemplate: "")

    // 字符替换
    for (from, to) in [("**", ""), ("*", ""), ("`", ""), ("#", ""), (">", ""),
                        ("✅", ""), ("❌", ""), ("✓", ""), ("✗", ""), ("→", "到")] {
        s = s.replacingOccurrences(of: from, with: to)
    }

    s = s.trimmingCharacters(in: CharacterSet(charactersIn: " \t-:|"))
    s = multiSpaceRe.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: s.utf16.count), withTemplate: " ")
    return s.trimmingCharacters(in: .whitespaces)
}

private func isMostlyTableRow(_ line: String) -> Bool {
    guard line.contains("|") else { return false }
    return line.filter({ $0 == "|" }).count >= 2 && line.count > 40
}

private func isProgressNoiseLine(_ line: String) -> Bool {
    speedNoiseRe.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil ||
    etaNoiseRe.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) != nil
}
