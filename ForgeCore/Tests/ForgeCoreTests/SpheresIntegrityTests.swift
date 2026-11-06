import XCTest
@testable import ForgeCore

final class SpheresIntegrityTests: XCTestCase {
    func testPanelCoversEverySphere() {
        XCTAssertEqual(Set(Spheres.all.map(\.sphere)), Set(Sphere.allCases))
    }

    func testEveryProfileIsComplete() {
        for p in Spheres.all {
            XCTAssertFalse(p.judges.isEmpty, "\(p.sphere) judges")
            XCTAssertFalse(p.frameworks.isEmpty, "\(p.sphere) frameworks")
            XCTAssertFalse(p.willNotDo.isEmpty, "\(p.sphere) willNotDo")
            XCTAssertFalse(p.criteriaKeys.isEmpty, "\(p.sphere) criteria")
            for (lens, keys) in p.criteriaKeys {
                for k in keys {
                    XCTAssertNotNil(Lenses.criterion(k, in: lens), "\(p.sphere) judges unknown criterion \(k) in \(lens)")
                }
            }
        }
    }

    func testPhase3PanelExcludesSteward() {
        XCTAssertFalse(Sphere.phase3Panel.contains(.steward))
        XCTAssertEqual(Sphere.phase3Panel.count, 5)
        XCTAssertEqual(Spheres.steward.availableFromPhase, 5)
        for s in Sphere.phase3Panel { XCTAssertEqual(Spheres.profile(for: s).availableFromPhase, 3) }
    }

    func testEveryBusinessCriterionHasAJudge() {
        for c in Lenses.business.criteria {
            let judges = Spheres.all.filter { ($0.criteriaKeys[.business] ?? []).contains(c.key) && $0.sphere != .skeptic }
            XCTAssertFalse(judges.isEmpty, "\(c.key) has no Sphere besides the Skeptic")
        }
    }

    func testCommonRulesForbidGreatIdea() {
        XCTAssertTrue(Spheres.commonRules.contains { $0.contains("great idea") })
        XCTAssertEqual(Spheres.commonRules.count, 6)
        XCTAssertFalse(Spheres.charterPlaceholder.isEmpty)
    }
}
