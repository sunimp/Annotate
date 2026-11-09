//
//  LocalizationTests.swift
//  AnnotateTests
//
//  Created by Sun on 2026/11/9.
//

import XCTest

@testable import Annotate

/// Keeps the string catalogs complete: a string added in code without translations, or a
/// translation that drops a format specifier, fails here instead of shipping half translated.
/// Only the Xcode build compiles the catalogs, so this reads them as JSON.
final class LocalizationTests: XCTestCase {
    static let languages = ["zh-Hans", "zh-Hant", "ja", "es", "fr"]

    private func catalog(_ name: String) throws -> [String: [String: Any]] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Annotate/\(name).xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        return try XCTUnwrap(json?["strings"] as? [String: [String: Any]])
    }

    private func translation(_ entry: [String: Any], _ language: String) -> String? {
        let localizations = entry["localizations"] as? [String: Any]
        let unit = (localizations?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
        return unit?["value"] as? String
    }

    private func specifiers(_ text: String) -> [String] {
        let pattern = try? NSRegularExpression(pattern: #"%(?:\d+\$)?(?:lld|@|d)|\$\{\w+\}"#)
        let range = NSRange(text.startIndex..., in: text)
        return (pattern?.matches(in: text, range: range) ?? [])
            .compactMap { Range($0.range, in: text).map { String(text[$0]) } }
            .sorted()
    }

    func testEveryStringIsTranslatedWithTheSameSpecifiers() throws {
        for name in ["Localizable", "InfoPlist"] {
            for (key, entry) in try catalog(name) where entry["shouldTranslate"] as? Bool != false {
                let source = translation(entry, "en") ?? key
                for language in Self.languages {
                    guard let value = translation(entry, language) else {
                        XCTFail("\(name): \"\(key)\" has no \(language) translation")
                        continue
                    }
                    XCTAssertEqual(
                        specifiers(value),
                        specifiers(source),
                        "\(name) \(language): \"\(value)\" must keep the specifiers of \"\(source)\"")
                }
            }
        }
    }
}
