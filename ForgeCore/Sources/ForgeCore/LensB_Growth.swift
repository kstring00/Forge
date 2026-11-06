import Foundation

// Lens B — Personal Growth. Frameworks: Atomic Habits, values alignment, Deep Work.
// Evidence under this lens is behavioural: did I actually do the small version?
// Authored in Phase 0 so the integrity tests cover it; tone review is Phase 5.

public enum LensB {
    public static let lens = Lens(
        type: .growth,
        tagline: "Is this who I am becoming, and can I keep it up at the smallest size?",
        frameworks: [.atomicHabits, .valuesAlignment, .deepWork],
        criteria: [b1, b2, b3, b4, b5],
        confidenceNote: "Confidence here means: have I actually done the small version, and for how long?"
    )

    static let behaviourLadder: [LadderRung] = [
        LadderRung(0, "It sounds like me", description: "I have not written down why.", worth: "Not evidence."),
        LadderRung(1, "Reason written", description: "I have written why this matters and what the smallest version is.", worth: "A commitment I can check."),
        LadderRung(2, "Done once", description: "I did the smallest version one time.", worth: "A start, nothing more."),
        LadderRung(3, "Two weeks at the smallest size", description: "I ran the smallest version for two weeks without missing more than twice.", worth: "The habit is possible."),
        LadderRung(4, "A month alongside everything else", description: "Kept up for a month through normal work, family and rest.", worth: "Sustainable in real life."),
        LadderRung(5, "Noticed by someone else", description: "Three months in, or someone close to me has noticed a change without being told.", worth: "It has become part of who I am.")
    ]

    static let aiBoundary = "The AI can help you name the smallest version and spot where it conflicts with your week. It cannot do the two weeks for you, and it will not tell you a habit fits your values; only you can."

    static let b1 = Criterion(
        key: "B1", title: "Identity & values alignment",
        frameworks: [.atomicHabits, .valuesAlignment],
        definition: """
        Does this match who I am becoming, not just what sounds impressive? Atomic Habits puts identity before outcomes: every action is a vote for the kind of person you are. A goal that sounds admirable but belongs to someone else's life gets abandoned the first hard week. The test is whether you can say, in a sentence, which of your values this serves and which you would be trading away.
        """,
        rubric: Rubric([
            1: "It sounds impressive, and I could not say which value it serves.",
            3: "I can name the value it serves and the person it makes me, and nothing I care about is traded away.",
            5: "People who know me would say this is obviously me, and I have already been doing a version of it unasked."
        ]),
        ladder: behaviourLadder,
        doesNotCount: ["Goals I admire in other people.", "Things I think I should want."],
        playbook: [
            PlaybookStep("Write the identity sentence", "\"I am the kind of person who ___.\" If the blank feels borrowed, say so.", reachesRung: 1, effort: "ten minutes"),
            PlaybookStep("Name the trade", "What gets less time if this gets more? Write it down and decide if that is acceptable.", reachesRung: 1, effort: "ten minutes"),
            PlaybookStep("Do the smallest version for two weeks", "Not the full plan. The two-minute version. Record each day you did it.", reachesRung: 3, effort: "two weeks")
        ],
        shortfallTemplate: "You are at rung {rung} on identity. To reach rung {next}, {step}.",
        aiBoundary: aiBoundary)

    static let b2 = Criterion(
        key: "B2", title: "Skill compounding",
        frameworks: [.deepWork, .atomicHabits],
        definition: """
        Will the skill or habit built here keep paying off in other areas? Deep Work's argument is that rare, valuable skills come from focused practice and transfer across domains. Some growth is a dead end: impressive but isolated. The question is what else gets easier if you get good at this.
        """,
        rubric: Rubric([
            1: "Useful only for this one thing.",
            3: "I can name two other areas of my life or work that get easier if I build this.",
            5: "It is a foundation skill: it makes most of what I want to do next cheaper, and I have already seen it transfer once."
        ]),
        ladder: behaviourLadder,
        doesNotCount: ["Skills that are fun to collect but I never use.", "Credentials without practice."],
        playbook: [
            PlaybookStep("List what else it unlocks", "Two concrete places this skill shows up elsewhere in your life. If you cannot find two, it may still be worth it, but score it honestly.", reachesRung: 1, effort: "ten minutes"),
            PlaybookStep("Protect one deep-work block", "One ninety-minute block a week for the skill, for two weeks. See whether it survives.", reachesRung: 3, effort: "two weeks")
        ],
        shortfallTemplate: "You are at rung {rung} on skill compounding. To reach rung {next}, {step}.",
        aiBoundary: aiBoundary)

    static let b3 = Criterion(
        key: "B3", title: "Sustainability",
        frameworks: [.atomicHabits],
        definition: """
        Can I realistically keep this up alongside work, faith, family and rest? What is the smallest version I would never skip? Atomic Habits' rule is to make it easy: a habit that needs a perfect week will not survive an ordinary one. Run it for two weeks at the smallest size before committing to anything larger.
        """,
        rubric: Rubric([
            1: "Needs a free evening and a good mood.",
            3: "I have a smallest version that takes under ten minutes and fits an ordinary bad day.",
            5: "I have run the smallest version for a month, through travel or illness, without resenting it."
        ]),
        ladder: behaviourLadder,
        doesNotCount: ["Plans that start 'once things calm down'.", "A streak, which is pressure, not evidence."],
        playbook: [
            PlaybookStep("Shrink it until it is embarrassing", "What is the version so small you would never skip it? Two minutes. One sentence. One rep.", reachesRung: 1, effort: "ten minutes"),
            PlaybookStep("Run two weeks at that size", "Record done or not done. Missing twice is fine. Missing three days in a row means the size is wrong.", reachesRung: 3, effort: "two weeks"),
            PlaybookStep("Attach it to something that already happens", "After coffee, before the commute, with the evening dishes. Write the cue down.", reachesRung: 2, effort: "ten minutes")
        ],
        shortfallTemplate: "You are at rung {rung} on sustainability. To reach rung {next}, {step}.",
        aiBoundary: aiBoundary)

    static let b4 = Criterion(
        key: "B4", title: "Life & relationship impact",
        frameworks: [.valuesAlignment],
        definition: """
        Does it improve my life or the lives of people around me? Growth that costs the people close to you is a trade, not a gain. The honest test is to ask them, and to notice what the small version changes in a normal week.
        """,
        rubric: Rubric([
            1: "It is for me, and it takes time from people who would notice.",
            3: "It costs nothing anyone would notice, and I can name one way it helps someone else.",
            5: "Someone close to me has said they see the difference."
        ]),
        ladder: behaviourLadder,
        doesNotCount: ["Benefits to others I have imagined but not asked about."],
        playbook: [
            PlaybookStep("Ask one person", "Tell someone close to you what you are trying and ask what they think it would cost them. Listen.", reachesRung: 2, effort: "a conversation"),
            PlaybookStep("Notice after two weeks", "Did anything in a normal week get better for anyone? Write one line.", reachesRung: 3, effort: "two weeks")
        ],
        shortfallTemplate: "You are at rung {rung} on life impact. To reach rung {next}, {step}.",
        aiBoundary: aiBoundary)

    static let b5 = Criterion(
        key: "B5", title: "Intrinsic motivation",
        frameworks: [.atomicHabits],
        definition: """
        Would I do this if nobody ever knew? Growth driven by an audience ends when the audience looks away. The test is whether you have done any of it in private, unprompted, and whether you looked forward to it.
        """,
        rubric: Rubric([
            1: "I mostly want to have done it, or to be seen doing it.",
            3: "I have done some of it privately and enjoyed parts of it.",
            5: "I already do a version of this when nobody is watching, and I would keep going with no result to show."
        ]),
        ladder: behaviourLadder,
        doesNotCount: ["Wanting the result without wanting the practice.", "Enthusiasm on day one."],
        playbook: [
            PlaybookStep("Do it in private for two weeks", "No posting, no telling anyone. Record each day. Note whether you still wanted to on day ten.", reachesRung: 3, effort: "two weeks"),
            PlaybookStep("Write what you would keep if it never paid off", "If the outcome never came, which part would you still do?", reachesRung: 1, effort: "ten minutes")
        ],
        shortfallTemplate: "You are at rung {rung} on intrinsic motivation. To reach rung {next}, {step}.",
        aiBoundary: aiBoundary)
}
