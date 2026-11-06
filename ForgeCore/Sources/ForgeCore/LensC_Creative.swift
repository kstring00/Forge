import Foundation

// Lens C — Creative Experiment. A creative idea can score 90 with zero
// commercial potential; that is intentional. Confidence = have I made the
// smallest prototype yet? Authored in Phase 0 for test coverage; tone review is Phase 5.

public enum LensC {
    public static let lens = Lens(
        type: .creative,
        tagline: "Do I want to make this, and have I made the smallest version yet?",
        frameworks: [.buildMeasureLearn],
        criteria: [c1, c2, c3, c4, c5],
        confidenceNote: "Confidence here means one thing: have I made the smallest prototype yet, and did I come back to it?"
    )

    static let prototypeLadder: [LadderRung] = [
        LadderRung(0, "Idea only", description: "It exists in my head.", worth: "Not evidence."),
        LadderRung(1, "Sketched", description: "Notes, a sketch, a reference list.", worth: "Something to react to."),
        LadderRung(2, "One rough session", description: "I spent one sitting making a piece of it, however bad.", worth: "I know what it feels like to make."),
        LadderRung(3, "Smallest prototype exists", description: "A complete, tiny version: one page, one minute, one object.", worth: "It is real."),
        LadderRung(4, "Shown or iterated", description: "I showed it to someone, or made a second version.", worth: "It survived contact."),
        LadderRung(5, "Came back unplanned", description: "I returned to it without scheduling it.", worth: "It has pull.")
    ]

    static let aiBoundary = "The AI can suggest references, smallest-prototype shapes and what to try first. It cannot make the prototype, and it will not tell you whether you are excited."

    static let c1 = Criterion(
        key: "C1", title: "Genuine excitement",
        frameworks: [.buildMeasureLearn],
        definition: """
        Do I actually want to make this, or do I want to have made it? Excitement that survives a rough first session is the real kind. Excitement that only exists while describing the idea is the other kind.
        """,
        rubric: Rubric([
            1: "I like the idea of it.",
            3: "I have started, and I thought about it when I was not working on it.",
            5: "I keep returning to it without deciding to."
        ]),
        ladder: prototypeLadder,
        doesNotCount: ["How it would look finished.", "Other people's enthusiasm for it."],
        playbook: [
            PlaybookStep("One rough session", "Thirty minutes, no plan to show anyone. Notice whether you wanted a second one.", reachesRung: 2, effort: "half an hour"),
            PlaybookStep("Leave it for three days", "Do not touch it. Notice whether it comes back on its own.", reachesRung: 5, effort: "three days")
        ],
        shortfallTemplate: "You are at rung {rung} on excitement. To reach rung {next}, {step}.",
        aiBoundary: aiBoundary)

    static let c2 = Criterion(
        key: "C2", title: "Originality / exploration",
        frameworks: [.buildMeasureLearn],
        definition: """
        Is this taking me somewhere I have not been, or repeating something I already know how to do? Originality here is personal: new to me counts. The question is whether the project explores, not whether it is unprecedented.
        """,
        rubric: Rubric([
            1: "I have done this before in a slightly different coat.",
            3: "One element is new to me: a medium, a constraint, a subject.",
            5: "I do not know how it will turn out, and that is the point."
        ]),
        ladder: prototypeLadder,
        doesNotCount: ["Novelty for its own sake.", "Being first, which nobody can check."],
        playbook: [
            PlaybookStep("Name the unknown", "Write the one thing you cannot predict about the result.", reachesRung: 1, effort: "ten minutes"),
            PlaybookStep("Add one constraint", "A limit you have never worked under. See what it forces.", reachesRung: 2, effort: "one session"),
            PlaybookStep("Finish a tiny version under that constraint", "Complete, not polished. The unknown you named should now have an answer, even a bad one.", reachesRung: 3, effort: "this week")
        ],
        shortfallTemplate: "You are at rung {rung} on originality. To reach rung {next}, {step}.",
        aiBoundary: aiBoundary)

    static let c3 = Criterion(
        key: "C3", title: "Learning potential",
        frameworks: [.buildMeasureLearn, .deepWork],
        definition: """
        What will I be able to do afterwards that I cannot do now? A creative experiment pays in skill even when the result goes in a drawer. Name the skill before you start so you can tell whether you got it.
        """,
        rubric: Rubric([
            1: "I would finish knowing what I already know.",
            3: "I can name one skill or technique I would come out with.",
            5: "The project is built around a skill I want, and the result is almost beside the point."
        ]),
        ladder: prototypeLadder,
        doesNotCount: ["Vague 'growth'.", "Learning about the tool rather than the craft."],
        playbook: [
            PlaybookStep("Write the after-sentence", "\"When this is done I will be able to ___.\"", reachesRung: 1, effort: "ten minutes"),
            PlaybookStep("Make the smallest thing that uses the skill", "Not the whole project. The one part that needs the new thing.", reachesRung: 3, effort: "one session")
        ],
        shortfallTemplate: "You are at rung {rung} on learning. To reach rung {next}, {step}.",
        aiBoundary: aiBoundary)

    static let c4 = Criterion(
        key: "C4", title: "Feasibility of a small prototype",
        frameworks: [.buildMeasureLearn],
        definition: """
        Can I make a complete, tiny version this week with what I have? One page, one minute of sound, one object, one scene. If the smallest version needs gear, money or a month, the idea is not ready to be tested, only admired.
        """,
        rubric: Rubric([
            1: "The smallest version I can picture still needs weeks or things I do not own.",
            3: "I could make a rough complete version in a weekend with what I have.",
            5: "I could make it tonight, and I know exactly what it would be."
        ]),
        ladder: prototypeLadder,
        doesNotCount: ["Plans that start with buying something.", "A prototype that is a plan for a prototype."],
        playbook: [
            PlaybookStep("Define 'complete and tiny'", "What is the smallest thing that is finished? Write it in one line.", reachesRung: 1, effort: "ten minutes"),
            PlaybookStep("Make it this week", "Badly is fine. Finished is the point.", reachesRung: 3, effort: "this week")
        ],
        shortfallTemplate: "You are at rung {rung} on prototype feasibility. To reach rung {next}, {step}.",
        aiBoundary: aiBoundary)

    static let c5 = Criterion(
        key: "C5", title: "Enjoyment of the process",
        frameworks: [.buildMeasureLearn],
        definition: """
        Do I like doing this, not just having done it? Some work is worth the grind; a creative experiment usually is not. If the first session was miserable and you want to continue anyway, say why.
        """,
        rubric: Rubric([
            1: "I would endure it for the result.",
            3: "Parts of it are a pleasure, and I know which parts.",
            5: "I lose track of time doing it."
        ]),
        ladder: prototypeLadder,
        doesNotCount: ["Pride in the finished thing.", "Enjoying planning it."],
        playbook: [
            PlaybookStep("Do one session and write one line after", "Not about the result. About how the hour felt.", reachesRung: 2, effort: "one session"),
            PlaybookStep("Find the part you like and do more of that", "If one stage is the pleasure, shape the project around it.", reachesRung: 3, effort: "one session")
        ],
        shortfallTemplate: "You are at rung {rung} on enjoyment. To reach rung {next}, {step}.",
        aiBoundary: aiBoundary)
}
