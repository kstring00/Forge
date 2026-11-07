import Foundation
import ForgeCore

// Emits the lens content, Sphere profiles and Explore prompts as JSON so the
// proxy's prompts share the app's single source of truth.
// Usage: swift run forge-lens-export > proxy/lib/content.json

struct RungDTO: Encodable { let level: Int; let label: String; let description: String; let worth: String }
struct StepDTO: Encodable { let title: String; let body: String; let reachesRung: Int; let effort: String }
struct CriterionDTO: Encodable {
    let key: String; let title: String; let alias: String?; let frameworks: [String]
    let definition: String; let rubric: [String: String]; let ladder: [RungDTO]
    let doesNotCount: [String]; let playbook: [StepDTO]; let aiBoundary: String; let scoreEqualsLadder: Bool
}
struct LensDTO: Encodable { let type: String; let name: String; let tagline: String; let frameworks: [String]; let criteria: [CriterionDTO]; let confidenceNote: String }
struct SphereDTO: Encodable { let sphere: String; let judges: String; let frameworks: [String]; let willNotDo: String; let criteriaKeys: [String: [String]]; let availableFromPhase: Int }
struct PromptDTO: Encodable { let key: String; let question: String; let hint: String; let sphere: String? }
struct ContentDTO: Encodable {
    let version: Int
    let lenses: [LensDTO]
    let spheres: [SphereDTO]
    let sphereRules: [String]
    let explorePrompts: [PromptDTO]
    let recommendations: [String]
    let deskResearchRungCeiling: Int
}

let lenses = Lenses.all.map { lens in
    LensDTO(type: lens.type.rawValue, name: lens.name, tagline: lens.tagline,
            frameworks: lens.frameworks.map(\.name),
            criteria: lens.criteria.map { c in
                CriterionDTO(key: c.key, title: c.title, alias: c.alias, frameworks: c.frameworks.map(\.name),
                             definition: c.definition,
                             rubric: Dictionary(uniqueKeysWithValues: c.rubric.anchors.map { (String($0.key), $0.value) }),
                             ladder: c.ladder.map { RungDTO(level: $0.level, label: $0.label, description: $0.description, worth: $0.worth) },
                             doesNotCount: c.doesNotCount,
                             playbook: c.playbook.map { StepDTO(title: $0.title, body: $0.body, reachesRung: $0.reachesRung, effort: $0.effort) },
                             aiBoundary: c.aiBoundary, scoreEqualsLadder: c.scoreEqualsLadder)
            },
            confidenceNote: lens.confidenceNote)
}
let spheres = Spheres.all.map { p in
    SphereDTO(sphere: p.sphere.rawValue, judges: p.judges, frameworks: p.frameworks.map(\.name), willNotDo: p.willNotDo,
              criteriaKeys: Dictionary(uniqueKeysWithValues: p.criteriaKeys.map { ($0.key.rawValue, $0.value) }),
              availableFromPhase: p.availableFromPhase)
}
let content = ContentDTO(
    version: 1, lenses: lenses, spheres: spheres, sphereRules: Spheres.commonRules,
    explorePrompts: ExplorePrompts.all.map { PromptDTO(key: $0.key, question: $0.question, hint: $0.hint, sphere: $0.sphere?.rawValue) },
    recommendations: Recommendation.allCases.map(\.rawValue),
    deskResearchRungCeiling: Scoring.deskResearchRungCeiling)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(content)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write("\n".data(using: .utf8)!)
