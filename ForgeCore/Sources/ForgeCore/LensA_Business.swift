import Foundation

// Lens A — Business.
// Frameworks: The Mom Test, The Lean Startup, $100M Offers, $100M Leads,
// Blue Ocean Strategy, Good Strategy/Bad Strategy, 12 Months to $1 Million.
// A2 is the approved reference for tone. Edit text here, never in views.

public enum LensA {
    public static let lens = Lens(
        type: .business,
        tagline: "Would strangers give up time or money for this, and could I reach them?",
        frameworks: [.momTest, .leanStartup, .hundredMOffers, .hundredMLeads,
                     .blueOcean, .goodStrategy, .twelveMonths],
        criteria: [a1, a2, a3, a4, a5, a6],
        confidenceNote: "Confidence here means: how much of this assessment rests on what real people have done, rather than on what I believe."
    )

    // MARK: A1 — Problem reality

    static let a1 = Criterion(
        key: "A1",
        title: "Problem reality",
        frameworks: [.momTest],
        definition: """
        Who has this problem, how often, and how painful or expensive is it? Measured by what people do about it, not what they say about it.

        A problem is real when people are already spending something on it: time, money, or an awkward workaround they complain about. A problem you invented will sound real in your head and vanish the moment you ask someone to describe the last time it happened to them. The Mom Test's method is to ask about the specific past, "when did this last come up, what did you do," and to listen for the workaround. If there is no workaround, the pain is probably not big enough to pay for.
        """,
        rubric: Rubric([
            1: "I assume people have it. I have not asked anyone to describe the last time it happened.",
            3: "People have described the problem to me unprompted, or they already pay for a workaround.",
            5: "Multiple specific people have shown me their current workaround, what it costs them, and what they have already tried."
        ]),
        ladder: [
            LadderRung(0, "Assumption", description: "I believe people have this problem.", worth: "A starting point, not evidence."),
            LadderRung(1, "My own anecdotes", description: "I have it, or I remember someone mentioning it.", worth: "One data point, and a biased one."),
            LadderRung(2, "One person, unprompted", description: "Someone described the problem before I mentioned my idea.", worth: "The first sign it exists outside my head."),
            LadderRung(3, "Several people, with specifics", description: "Three or more people described when it last happened and what it cost them.", worth: "A pattern. The problem is real for a group."),
            LadderRung(4, "A paid or costly workaround", description: "People are currently spending money or hours on a clumsy fix.", worth: "Strong. Spending is the clearest sign of pain."),
            LadderRung(5, "Workaround observed and costed", description: "I have watched the workaround in use and written down what it costs, in time or money, per person.", worth: "As solid as problem evidence gets.")
        ],
        doesNotCount: [
            "People agreeing that the problem 'sounds annoying' when I describe it.",
            "My own frustration, however real. One person is an anecdote.",
            "Problems people say they have but have never tried to fix."
        ],
        playbook: [
            PlaybookStep("Have five past-behaviour conversations",
                "Ask when the problem last came up, what they did about it, what it cost, and what else they tried. Never ask whether they would use your idea. Write their words down as a source.",
                reachesRung: 4, effort: "this week"),
            PlaybookStep("Read where these people complain",
                "Find the communities, forums and review sites where they gather. Search for the problem in their words, not yours. Save threads that describe a workaround.",
                reachesRung: 3, effort: "an afternoon"),
            PlaybookStep("Look at what they already pay for",
                "List every product, service or hire that currently touches this problem. If money is changing hands, the pain is real.",
                reachesRung: 4, effort: "an hour")
        ],
        shortfallTemplate: "You are at rung {rung} on problem reality. To reach rung {next}, {step}.",
        aiBoundary: "The AI can find complaint threads and paid workarounds and save them as unreviewed sources. It cannot have the conversations for you, and it will not claim people have this problem on your behalf."
    )

    // MARK: A2 — Demand evidence (approved reference text)

    static let a2 = Criterion(
        key: "A2",
        title: "Demand evidence",
        alias: "commercial traction",
        frameworks: [.momTest, .leanStartup],
        definition: """
        Commercial traction is proof that people will give up something they value, time, attention, or money, to get this problem solved. Compliments are not traction. "That's a great idea" is worth zero.

        This criterion asks one question: what have real people actually done about this problem? Not what they said they would do. Not what you believe they would do. What they did, with their calendar, their inbox, or their wallet.

        It is the criterion most often faked by enthusiasm, which is why FORGE treats it differently from the other five. Everyone who describes their idea gets told it is good. That is politeness, not data. The Mom Test's rule is to talk about the other person's life and past behaviour and never pitch. The Lean Startup's rule is that an idea is a hypothesis until a measurable behaviour confirms it. Put together: demand is measured by behaviour, and ranked by how much that behaviour cost the person who did it.

        Your score on this criterion is the highest rung that at least three independent people have reached. One person at a high rung is a promising signal and FORGE will note it, but it does not move the score. Three is the minimum before a pattern is more than a story. Independent means: not family, not close friends, not people who would say yes to be helpful, and not three people from the same conversation.
        """,
        rubric: Rubric([
            1: "Enthusiasm. Rung 0 or 1. Nobody has done anything. You might be right. You do not yet know.",
            2: "Problem confirmed. Rung 2 with three or more people. The pain is real and people are already paying for it somehow. Whether they would pay you is still open.",
            3: "Attention given. Rung 3 with three or more people. Strangers have spent time on this. You have something worth testing with money.",
            4: "Money changed hands. Rung 4 with three or more people. You have a business hypothesis with early proof. The risk has moved from 'does anyone want this' to 'can I deliver and repeat it.'",
            5: "Repeat behaviour. Rung 5 with three or more people. Demand is demonstrated. This criterion is no longer your riskiest assumption; look at distribution and economics instead."
        ]),
        ladder: [
            LadderRung(0, "I think it's good",
                description: "This is where every idea starts, and there is no shame in it.",
                worth: "Nothing. It is just not evidence."),
            LadderRung(1, "People said it's a good idea",
                description: "Compliments are what people give when they want the conversation to end pleasantly.",
                worth: "Nothing. Hunch will say so plainly. Count them, then set them aside."),
            LadderRung(2, "People described the problem, or already pay for a workaround",
                description: "Someone volunteered the pain before you mentioned your idea, or you can point to money or hours they already spend on a clumsy fix.",
                worth: "The first real rung. This proves the problem is real. It does not yet prove they want your solution."),
            LadderRung(3, "People gave time",
                description: "An interview about their past behaviour. A waitlist signup. A demo request. A reply to a cold message that asks a question.",
                worth: "Time is the first thing people refuse to spend on things they do not care about."),
            LadderRung(4, "People gave money",
                description: "A preorder. A deposit. A paid pilot, even a tiny one. A signed letter of intent.",
                worth: "The clearest signal there is, because money is the hardest thing to get from someone out of politeness."),
            LadderRung(5, "People came back",
                description: "Renewed. Reordered. Referred someone else. Used the manual version a second time without being reminded.",
                worth: "The only rung that proves the solution works, not just that the problem exists.")
        ],
        doesNotCount: [
            "Likes, follows, upvotes, or views. Attention that cost nothing is rung 1 at best.",
            "\"I would totally buy that.\" Future-tense statements are rung 1. Only past-tense actions count.",
            "Friends, family, and anyone who would be uncomfortable saying no.",
            "Your own excitement, however strong.",
            "AI summaries or AI-found sources you have not read yourself. These stay 'found by AI' until you mark them reviewed; then they can support rung 2.",
            "A competitor's existence on its own. That proves the category is paid for, which supports rung 2, but says nothing about rungs 3 to 5 for your idea."
        ],
        playbook: [
            PlaybookStep("Find who already gets paid",
                "Search for products or services that solve this problem today. Save their pricing pages. If people are paying, the problem is real. Save their one-star reviews too; those are the complaints nobody has fixed, and they feed Differentiation as well.",
                reachesRung: 2, effort: "an hour"),
            PlaybookStep("Check search volume",
                "Type the problem, not your solution, into Google and watch autocomplete. Use Google Trends and the free Keyword Planner for the top three phrases. Volume is a rough proxy for how many people are actively looking.",
                reachesRung: 2, effort: "an hour"),
            PlaybookStep("Read the complaint threads",
                "Reddit, Facebook groups, niche forums, G2 and Capterra reviews. Search for 'how do you deal with', 'is there a tool for', 'anyone else frustrated by'. Save threads where people describe their workaround in detail. Each distinct person is one toward your three.",
                reachesRung: 2, effort: "an afternoon"),
            PlaybookStep("Look at job postings",
                "If companies are hiring someone to handle this problem by hand, companies are already spending on it. Search LinkedIn and Indeed for the task, not the title.",
                reachesRung: 2, effort: "an hour"),
            PlaybookStep("Have five Mom Test conversations",
                "Talk to people who might have the problem about their life, not your idea. Ask: 'When did this last come up?' 'What did you do about it?' 'What did that cost you?' 'What else have you tried?' 'Who else has this?' Never ask 'would you use this?' If they describe the problem and a workaround unprompted, that is rung 2. If they ask to see what you are building, that is rung 3. Write down what they said in their words.",
                reachesRung: 3, effort: "this week"),
            PlaybookStep("Send twenty cold messages",
                "Short, specific, about their problem, not your product. Record every reply. Replies with a question in them are rung 3. Silence is data too; it tells you the problem is not top of mind for that group.",
                reachesRung: 3, effort: "this week"),
            PlaybookStep("Landing page, waitlist, fifty dollars of ads",
                "One page, one promise, one email field. Send a small amount of paid traffic from where these people already are. A signup is rung 3. Be honest on the page that it is not built yet.",
                reachesRung: 3, effort: "one to two weeks"),
            PlaybookStep("Fake-door test, disclosed",
                "A 'Get started' button that leads to 'Not ready yet. Leave your email and I'll tell you when.' Ethical only if you tell them on that page. Each email is rung 3.",
                reachesRung: 3, effort: "one to two weeks"),
            PlaybookStep("Sell the manual version to one customer",
                "Before building anything, do the job by hand for one person and charge for it. This is the single most informative test on the ladder: it reaches rung 4 and teaches you exactly what the product has to do. If you cannot find one person to pay for a manual version, no amount of software will change that.",
                reachesRung: 4, effort: "two to four weeks"),
            PlaybookStep("Take a deposit or preorder",
                "Even a small, refundable one. Or a signed letter of intent from a business buyer. Three of these and the score is a 4.",
                reachesRung: 4, effort: "two to four weeks"),
            PlaybookStep("See if they come back",
                "Did the manual-version customer ask for it again? Did a preorder customer refer someone? Did anyone use it a second time without a nudge? You cannot manufacture this rung. You can only set it up and watch.",
                reachesRung: 5, effort: "wait and watch")
        ],
        shortfallTemplate: "You are at rung {rung} with {count} of 3 people. To reach rung {next}, {step}.",
        aiBoundary: "The AI can run the desk research steps through the Library and save what it finds as unreviewed sources. Those raise Confidence only after you read them and mark them reviewed. The AI can draft the five interview questions and the twenty outreach messages. It cannot do the conversations, tests or sales for you, and it will never claim rung 3 or above on your behalf, because those rungs are things real people did.",
        scoreEqualsLadder: true
    )

    // MARK: A3 — Differentiation

    static let a3 = Criterion(
        key: "A3",
        title: "Differentiation",
        frameworks: [.blueOcean],
        definition: """
        Why would someone pick this over what they use now? "Now" includes doing nothing, a spreadsheet, a cheaper competitor, and a person they already pay.

        Blue Ocean Strategy's Four Actions give the test. For the factors your industry competes on, which would you eliminate, reduce, raise, or create? If the honest answer is "I'd do the same things, better," you are competing on execution against people with a head start. Differentiation is a different value curve: you drop something everyone assumes is required and add something nobody offers, and the buyers you want have told you that trade matters to them.
        """,
        rubric: Rubric([
            1: "Same as the alternatives, but I would do it better.",
            3: "One clear factor I would raise or create that the alternatives ignore.",
            5: "A different value curve. I eliminate things competitors assume are required and create something they do not offer, and target buyers have told me that factor matters."
        ]),
        ladder: [
            LadderRung(0, "I'd do it better", description: "I believe mine would be better without having compared.", worth: "Not evidence."),
            LadderRung(1, "Alternatives listed", description: "I have written down what people use today, including 'nothing' and 'spreadsheet'.", worth: "The minimum before any claim."),
            LadderRung(2, "Three competitors mapped", description: "Pricing, features and positioning for three alternatives, side by side.", worth: "I can now see the industry's assumed factors."),
            LadderRung(3, "An unfixed complaint found", description: "Their one-star reviews and complaint threads point at something nobody addresses.", worth: "A candidate for raise or create."),
            LadderRung(4, "Buyers said the factor matters", description: "Three or more target buyers told me, unprompted, that this factor is why they would switch.", worth: "The curve is different in their eyes, not just mine."),
            LadderRung(5, "Chosen for that reason", description: "Someone picked my version over an alternative and named that factor as why.", worth: "Differentiation that converts.")
        ],
        doesNotCount: [
            "Features I like that no buyer has asked about.",
            "'Better design' or 'better UX' as the only difference.",
            "Being cheaper, unless I can stay cheaper."
        ],
        playbook: [
            PlaybookStep("List every alternative, honestly",
                "Include 'do nothing', 'a spreadsheet', 'hire someone' and the market leader. This is the competition.",
                reachesRung: 1, effort: "an hour"),
            PlaybookStep("Map three competitors",
                "For each: price, main features, who it is for, and its three loudest one-star reviews. Save each page as a source.",
                reachesRung: 3, effort: "an afternoon"),
            PlaybookStep("Fill the ERRC grid",
                "Eliminate, Reduce, Raise, Create. Which industry assumptions can go? What do customers complain about that nobody fixes? What does everyone offer that customers do not care about?",
                reachesRung: 3, effort: "an hour"),
            PlaybookStep("Ask buyers which factor would make them switch",
                "In your Mom Test conversations, ask what they would need to see to leave their current tool. Record the factor in their words.",
                reachesRung: 4, effort: "this week")
        ],
        shortfallTemplate: "You are at rung {rung} on differentiation. To reach rung {next}, {step}.",
        aiBoundary: "The AI can map competitors, pull pricing pages and summarise one-star reviews as unreviewed sources. It cannot tell you which factor buyers care about; only buyers can."
    )

    // MARK: A4 — Offer strength

    static let a4 = Criterion(
        key: "A4",
        title: "Offer strength",
        frameworks: [.hundredMOffers],
        definition: """
        How good is the deal from the buyer's side? The value equation from $100M Offers: value = (dream outcome × perceived likelihood of achieving it) ÷ (time delay × effort and sacrifice).

        Four questions. What outcome does the buyer actually want, in their words? How believable is it that this gets them there? How long until they feel it? How much do they have to do or give up along the way? A strong offer names a specific outcome the buyer already wants, delivers it fast, asks little of them, and comes with a believable reason it works. A weak offer is a vague improvement, someday, with effort.
        """,
        rubric: Rubric([
            1: "Vague outcome, slow, effortful.",
            3: "Clear outcome, moderate wait, some effort.",
            5: "A specific outcome the buyer already wants, fast, nearly effortless, with a believable reason it works."
        ]),
        ladder: [
            LadderRung(0, "I think it's valuable", description: "I have not written the outcome down.", worth: "Not evidence."),
            LadderRung(1, "Outcome written", description: "I have written the dream outcome and the four value-equation answers.", worth: "A hypothesis I can test."),
            LadderRung(2, "Alternatives timed", description: "I have measured how long and how many steps the current alternatives take.", worth: "I know what 'fast' and 'effortless' have to beat."),
            LadderRung(3, "Outcome in their words", description: "Three or more prospects described the outcome they would pay for, in their own words, and it matches mine.", worth: "The offer is aimed at something real."),
            LadderRung(4, "Asked for the next step", description: "A prospect heard the offer and asked for price, timing or how to start.", worth: "The offer pulls."),
            LadderRung(5, "Paid for that outcome", description: "Someone paid for exactly this outcome, as stated.", worth: "The offer works.")
        ],
        doesNotCount: [
            "Outcomes I would want for them.",
            "A long feature list standing in for an outcome.",
            "'It saves time' without a number."
        ],
        playbook: [
            PlaybookStep("Write the four answers",
                "Dream outcome, perceived likelihood, time delay, effort. One sentence each. Then say the offer out loud in one breath.",
                reachesRung: 1, effort: "an hour"),
            PlaybookStep("Time the alternatives",
                "How long does the current way take, start to finish? How many steps? What do they have to learn or give up?",
                reachesRung: 2, effort: "an afternoon"),
            PlaybookStep("Ask prospects what outcome they'd pay for",
                "Not 'would you pay for X' but 'what would have to be true for this to be worth paying for?' Record their words.",
                reachesRung: 3, effort: "this week"),
            PlaybookStep("State the offer and watch the reaction",
                "At the end of a conversation, describe the offer plainly and stop talking. A question about price or start date is rung 4. A compliment is rung 1 on Demand evidence.",
                reachesRung: 4, effort: "this week")
        ],
        shortfallTemplate: "You are at rung {rung} on offer strength. To reach rung {next}, {step}.",
        aiBoundary: "The AI can help you phrase the four answers and draft offer wording. It cannot know what outcome a buyer wants until a buyer has said it."
    )

    // MARK: A5 — Distribution & economics

    static let a5 = Criterion(
        key: "A5",
        title: "Distribution & economics",
        frameworks: [.hundredMLeads, .leanStartup, .profitFirst],
        definition: """
        How do customers discover this, and does the money work? A product nobody finds is not a business, and a product that costs more to sell than it earns is a hobby with invoices.

        Two halves. Distribution: name the channel, not "word of mouth" or "social media" but a specific place you can reach these buyers today, and what it costs to get one of them to act. Economics: price above cost, the cost of acquiring a customer against what they pay in the first year, and whether the revenue can repeat through subscription, retainer or reorder. Profit First's question applies from sale one: is there profit in this sale, or only in a future that needs scale?
        """,
        rubric: Rubric([
            1: "'They'll find it.'",
            3: "One channel I can access today (existing clients, a community, outreach) and plausible pricing above cost.",
            5: "A named channel with a tested conversion rate, pricing validated by a real payment, and a path to recurring revenue."
        ]),
        ladder: [
            LadderRung(0, "They'll find it", description: "No channel named.", worth: "Not evidence."),
            LadderRung(1, "Buyers located", description: "I have listed where these buyers already gather and what they already pay for.", worth: "A place to start."),
            LadderRung(2, "One channel I can reach today", description: "A list, a community, existing clients, or an outreach method I can use this week, plus a price above cost on paper.", worth: "A plausible first sale."),
            LadderRung(3, "Outreach measured", description: "Twenty outreaches sent and replies recorded, or a small ad spend with a measured click or signup rate.", worth: "The channel has a number attached."),
            LadderRung(4, "Paid at the price", description: "A real payment at the stated price, with the acquisition cost known.", worth: "The economics exist for one customer."),
            LadderRung(5, "Revenue repeated", description: "A second payment from the same customer, or a referral that paid.", worth: "The money can repeat.")
        ],
        doesNotCount: [
            "'Social media' or 'SEO' without a specific place and a number.",
            "Pricing I would be comfortable with, rather than a price someone paid.",
            "Projections that only work at scale."
        ],
        playbook: [
            PlaybookStep("List where these buyers already are",
                "Communities, newsletters, events, the tools they use, the people they already pay. Pick the one you can reach this week.",
                reachesRung: 2, effort: "an hour"),
            PlaybookStep("Run twenty cold outreaches",
                "Same message, twenty people, one channel. Record sent, replied, interested. That ratio is your first conversion rate.",
                reachesRung: 3, effort: "this week"),
            PlaybookStep("Estimate CAC against first-year revenue",
                "How many outreaches or ad dollars per customer, against what one customer pays in a year? If it is upside down, change the channel or the price before building.",
                reachesRung: 3, effort: "an hour"),
            PlaybookStep("Check whether revenue can repeat",
                "Subscription, retainer, reorder, or one-off? If one-off, what is the second thing you sell them?",
                reachesRung: 4, effort: "an hour")
        ],
        shortfallTemplate: "You are at rung {rung} on distribution and economics. To reach rung {next}, {step}.",
        aiBoundary: "The AI can find where buyers gather and draft outreach messages. It cannot send them, and it will not invent conversion rates or prices."
    )

    // MARK: A6 — Feasibility & founder fit

    static let a6 = Criterion(
        key: "A6",
        title: "Feasibility & founder fit",
        frameworks: [.goodStrategy, .eMyth],
        definition: """
        Can I realistically build, launch and maintain the first useful version with my skills, time and money, and does it use an advantage I already have?

        Good Strategy, Bad Strategy asks for a diagnosis, a guiding policy and coherent action. The guiding policy that matters most for a solo builder is to lean on an existing advantage: a skill, an audience, a relationship, an asset. The E-Myth adds the second test: if the business only works while you do custom labour, you have built yourself a job. Feasibility is the honest answer to "what is the smallest usable version, how many hours, what must I learn, and what breaks if I stop?"
        """,
        rubric: Rubric([
            1: "Needs skills or capital I do not have and cannot get soon.",
            3: "Buildable in weeks with current skills and tools.",
            5: "Uses an existing advantage (skill, audience, relationships), buildable in days, and does not depend on me doing custom labour forever."
        ]),
        ladder: [
            LadderRung(0, "I think I can build it", description: "No plan written.", worth: "Not evidence."),
            LadderRung(1, "Smallest version written", description: "One paragraph describing the smallest usable version.", worth: "Something to estimate."),
            LadderRung(2, "Hours and gaps estimated", description: "An honest hour count and a list of what I would have to learn.", worth: "I know the cost."),
            LadderRung(3, "Hardest part spiked", description: "A throwaway version of the riskiest technical or operational piece works.", worth: "The unknown is now known."),
            LadderRung(4, "Smallest version built", description: "The one-paragraph version exists and someone has used it.", worth: "Feasible, demonstrated."),
            LadderRung(5, "Ran without me", description: "It delivered value for a week without custom labour from me.", worth: "A business, not a job.")
        ],
        doesNotCount: [
            "'I'll figure it out' as a plan for a skill gap.",
            "Hour estimates made without listing the tasks.",
            "An advantage I would like to have rather than one I have."
        ],
        playbook: [
            PlaybookStep("Write the smallest usable version in one paragraph",
                "What is the least this has to do for one person to get the outcome? Not the vision. The first version.",
                reachesRung: 1, effort: "an hour"),
            PlaybookStep("List what must be learned and estimate hours honestly",
                "Break the paragraph into tasks. Mark the ones you cannot do today. Add the hours. Double them.",
                reachesRung: 2, effort: "an hour"),
            PlaybookStep("Spike the hardest part",
                "Build a throwaway version of the riskiest piece in a day. If it cannot be done in a day, that is the finding.",
                reachesRung: 3, effort: "a day"),
            PlaybookStep("Ask what breaks if you stop",
                "If the answer is 'everything', the first version depends on your labour. Decide now whether that is acceptable for the first customers, and what replaces it.",
                reachesRung: 2, effort: "an hour")
        ],
        shortfallTemplate: "You are at rung {rung} on feasibility. To reach rung {next}, {step}.",
        aiBoundary: "The AI can help break the smallest version into tasks and flag skill gaps. It cannot estimate your hours, and it does not know your advantages unless you list them in Settings."
    )
}
