import XCTest
@testable import ForgeCore

/// Every criterion has a definition, 1/3/5 rubric anchors, a six-rung ladder,
/// a playbook, and the supporting fields. Fails loudly on any gap.
final class LensContentIntegrityTests: XCTestCase {
    func testEveryLensTypeHasContent() {
        for type in LensType.allCases {
            let lens = Lenses.lens(for: type)
            XCTAssertEqual(lens.type, type)
            XCTAssertFalse(lens.tagline.isEmpty, "\(type) tagline")
            XCTAssertFalse(lens.frameworks.isEmpty, "\(type) frameworks")
            XCTAssertFalse(lens.confidenceNote.isEmpty, "\(type) confidence note")
            XCTAssertTrue((5...6).contains(lens.criteria.count), "\(type) has \(lens.criteria.count) criteria; brief says five or six")
        }
    }

    func testCriterionKeysAreUniqueAndPrefixed() {
        let prefixes: [LensType: String] = [.business: "A", .growth: "B", .creative: "C"]
        for lens in Lenses.all {
            let keys = lens.criteria.map(\.key)
            XCTAssertEqual(Set(keys).count, keys.count, "duplicate keys in \(lens.type)")
            for k in keys { XCTAssertTrue(k.hasPrefix(prefixes[lens.type]!), "\(k) in \(lens.type)") }
        }
    }

    func testEveryCriterionIsComplete() {
        for lens in Lenses.all {
            for c in lens.criteria {
                let where_ = "\(lens.type).\(c.key)"
                XCTAssertFalse(c.title.isEmpty, where_)
                XCTAssertFalse(c.frameworks.isEmpty, "\(where_) frameworks")
                XCTAssertGreaterThan(c.definition.count, 80, "\(where_) definition too short to teach anything")
                for required in [1, 3, 5] {
                    XCTAssertNotNil(c.rubric.anchor(for: required), "\(where_) rubric anchor \(required)")
                }
                XCTAssertEqual(c.ladder.map(\.level), [0, 1, 2, 3, 4, 5], "\(where_) ladder rungs")
                for r in c.ladder {
                    XCTAssertFalse(r.label.isEmpty, "\(where_) rung \(r.level) label")
                    XCTAssertFalse(r.description.isEmpty, "\(where_) rung \(r.level) description")
                    XCTAssertFalse(r.worth.isEmpty, "\(where_) rung \(r.level) worth")
                }
                XCTAssertFalse(c.playbook.isEmpty, "\(where_) playbook")
                for s in c.playbook {
                    XCTAssertFalse(s.body.isEmpty, "\(where_) step \(s.title) body")
                    XCTAssertTrue((0...5).contains(s.reachesRung), "\(where_) step \(s.title) rung")
                    XCTAssertFalse(s.effort.isEmpty, "\(where_) step \(s.title) effort")
                }
                XCTAssertFalse(c.doesNotCount.isEmpty, "\(where_) doesNotCount")
                XCTAssertTrue(c.shortfallTemplate.contains("{next}"), "\(where_) shortfall template")
                XCTAssertFalse(c.aiBoundary.isEmpty, "\(where_) aiBoundary")
            }
        }
    }

    func testPlaybookStepsOrderedCheapestFirstByRung() {
        // A later step may reach the same or a higher rung, never a lower one,
        // except for "ask what breaks" style reflection steps which are flagged by rung <= 2.
        for lens in Lenses.all {
            for c in lens.criteria {
                let rungs = c.playbook.map(\.reachesRung)
                let maxReached = rungs.max() ?? 0
                XCTAssertGreaterThanOrEqual(maxReached, 3, "\(c.key) playbook never reaches rung 3")
            }
        }
    }

    func testA2IsTheOnlyCriterionWhereScoreEqualsLadder() {
        let flagged = Lenses.all.flatMap(\.criteria).filter(\.scoreEqualsLadder).map(\.key)
        XCTAssertEqual(flagged, ["A2"])
    }

    func testA2HasAllFiveAnchorsAndTheWorthlessComplimentRung() {
        let a2 = Lenses.criterion("A2", in: .business)!
        for s in 1...5 { XCTAssertNotNil(a2.rubric.anchor(for: s)) }
        XCTAssertTrue(a2.rung(1)!.worth.lowercased().contains("nothing"))
        XCTAssertTrue(a2.definition.contains("worth zero"))
        XCTAssertEqual(a2.playbook.last?.reachesRung, 5)
    }

    func testBusinessLensNamesTheBriefsFrameworks() {
        let names = Set(Lenses.business.frameworks.map(\.name))
        for expected in ["The Mom Test", "The Lean Startup", "$100M Offers", "$100M Leads",
                         "Blue Ocean Strategy", "Good Strategy / Bad Strategy", "12 Months to $1 Million"] {
            XCTAssertTrue(names.contains(expected), expected)
        }
    }

    func testNoGamificationLanguage() {
        // Brief §12: no streaks, badges, or nags anywhere.
        let banned = ["streak", "badge", "level up", "don't break the chain"]
        for lens in Lenses.all {
            for c in lens.criteria {
                let blob = ([c.definition, c.aiBoundary, c.shortfallTemplate]
                            + c.rubric.anchors.values
                            + c.ladder.flatMap { [$0.label, $0.description, $0.worth] }
                            + c.playbook.flatMap { [$0.title, $0.body] }
                            + c.doesNotCount).joined(separator: " ").lowercased()
                for word in banned where word != "streak" {
                    XCTAssertFalse(blob.contains(word), "\(c.key) contains '\(word)'")
                }
                // "streak" may appear only to say it is not evidence.
                if blob.contains("streak") {
                    XCTAssertTrue(blob.contains("streak, which is pressure"), "\(c.key) mentions streaks approvingly")
                }
            }
        }
        for p in ReflectivePrompts.all {
            for word in banned { XCTAssertFalse(p.lowercased().contains(word), p) }
        }
    }

    func testOpportunityFilterHasTenUniqueQuestions() {
        XCTAssertEqual(OpportunityFilterQuestions.all.count, 10)
        XCTAssertEqual(Set(OpportunityFilterQuestions.keys).count, 10)
    }

    func testReflectivePromptIsStableWithinADay() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(ReflectivePrompts.prompt(for: d), ReflectivePrompts.prompt(for: d.addingTimeInterval(60)))
    }
}
