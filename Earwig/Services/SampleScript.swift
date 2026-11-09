/// The built-in samples on the Scripts screen (plan 011), all made up: the repo is public. The
/// Harbour Walk is also the parser tests' main fixture (plan 002, decision 12).
enum SampleScript {
    static let harbourWalk = """
        # The Harbour Walk

        ## 1. Setting off
        Shows: Presenter at the harbour wall, boats behind.
        Says:
        - Morning! We're starting at the old harbour, just as the tide turns.
        - The plan is simple: along the sea wall, up the cliff path, and back through the village for a late breakfast.
        - It's about four miles in all, and if we don't stop too often, it should take a couple of hours.
        - [Gesture to the boats] Most of these boats go out at first light, so by now the harbour is almost empty.

        ## 2. The sea wall
        Shows: Walking shot along the wall, waves below.
        Says:
        - The sea wall was built in 1890, after a storm took half the cottages on the front.
        - You can still see the marks where the old ones stood, if you know where to look.
        - On a calm day like this it's an easy stroll, but in winter the spray comes right over the top.
        - The trick is to keep an eye on the tide tables, and never to be here at high water in a gale.

        ## 3. Up the cliff path
        Shows: Steep path, gorse either side.
        Says:
        - Now the hard part. The path climbs about three hundred feet in less than half a mile.
        - Take it steadily; there's a bench at the top, and the view is worth every step.
        - On a clear day you can see the lighthouse to the west, and the headland beyond it.
        - And if you're very lucky, there are seals on the rocks below, sleeping off their breakfast.
        - Which reminds me, it's time we thought about ours.
        """

    /// Quantities said as numbers and directions inside lines (plan 005, check 6). Exactly as pasted on the phone, so its copy is adopted (plan 011, decision 4).
    static let weekendLoaf = """
        # The Weekend Loaf

        ## 1. The kitchen
        Shows: Presenter at the counter, flour and a mixing bowl.
        Says:
        - Hello, and welcome to the kitchen. Today we're making a simple white loaf.
        - You only need four things: flour, water, salt and a little yeast.
        - It takes about three hours from start to finish, but most of that is waiting.
        - [Hold up the bag of flour] Strong bread flour is best, because it makes a lighter crumb.

        ## 2. Mixing
        Shows: Close on the bowl, hands mixing.
        Says:
        - Put 500 grams of flour in the bowl, with ten grams of salt on one side.
        - Add the yeast on the other side, so the salt doesn't touch it at first.
        - Pour in about 350 millilitres of warm water, and stir until there's no dry flour left.
        - It will look rough and sticky now, and that's exactly what we want.

        ## 3. Kneading
        Shows: Dough on the counter, presenter kneading.
        Says:
        - Tip the dough out and push it away with the heel of your hand.
        - Fold it back, turn it a quarter, and do it again.
        - Keep going for ten minutes, until it's smooth and springs back when you press it.
        - [Press the dough with a finger] If the dent fills in slowly, it's ready to rest.

        ## 4. The oven
        Shows: The finished loaf coming out of the oven.
        Says:
        - After an hour in a warm place, it should have doubled in size.
        - Shape it gently, leave it for another forty minutes, then bake it at 220 degrees.
        - Give the bottom a tap when it comes out; a hollow sound means it's done.
        - And the hardest part of all is waiting for it to cool before you cut it.
        """

    /// Long, with words the recogniser mishears ("leat"; plans 005, 009). Exactly as pasted on the phone.
    static let oldWatermill = """
        # The Old Watermill

        ## 1. Arriving at the mill
        Shows: Presenter on the footbridge, the mill behind, wheel still.
        Says:
        - Good morning. We're a few miles up the valley today, at a watermill that ground flour for this village for nearly three hundred years.
        - It stopped working in 1952, when the last miller retired and nobody wanted to take it on.
        - For a long time it was just a shell, with a tree growing out of the roof.
        - Then, about fifteen years ago, a handful of volunteers decided to bring it back.
        - [Turn to the wheel] And today, for the first time in a while, we're going to see it turn.

        ## 2. The leat and the pond
        Shows: Walking shot along the leat, water moving slowly beside the path.
        Says:
        - Everything here starts with the water, so that's where we'll start too.
        - This channel is called the leat. It takes water off the river about half a mile upstream and brings it round the hillside on a very gentle slope.
        - The fall over that half mile is only about six feet, which tells you how carefully the whole thing was surveyed, by eye and by level, long before anyone had a laser.
        - [Point ahead] It ends in the mill pond, just up there, which is really a storage tank with ducks on it.
        - The miller would fill it overnight and then have enough stored water for a full morning's grinding.

        ## 3. The wheel
        Shows: Close on the wheel, then wide as it starts to turn.
        Says:
        - Here's the heart of it. This is an overshot wheel, fourteen feet across, and it weighs the best part of two tons.
        - Overshot means the water comes in over the top and fills the buckets on the way down, so it's the weight of the water doing the work, not the speed of it.
        - That makes it very efficient. On a good day this wheel turns out something like eight horsepower, which doesn't sound much, until you remember it ran for free.
        - [Signal to open the sluice] Right. Let's see it go.
        - There. It takes a moment to get the first buckets full, and then it just rolls over and carries on. Listen to that.
        - The sound is the thing everyone remembers. Deep, steady, and a little bit alive.

        ## 4. Inside, the gears
        Shows: Interior, the pit wheel and wallower in the gloom, dust in the light.
        Says:
        - Follow me inside, and mind your head on the beam.
        - The wheel outside turns slowly, about six times a minute, and the millstones need to turn about a hundred and twenty.
        - So between the two there's a set of gears to speed things up, and they're all wood and iron together.
        - This big one is the pit wheel, cast iron, bolted to the same shaft as the water wheel.
        - It drives this smaller one, called the wallower, and the teeth on it are made of apple wood.
        - [Tap a tooth] Wood against iron sounds like a bad idea, but it's quiet, it doesn't spark, and when a tooth wears out you can carve a new one in an afternoon.
        - The millers had a rule: iron on iron never, wood on wood rarely, wood on iron always.

        ## 5. The stones
        Shows: Upstairs, the stone floor, the hopper feeding grain.
        Says:
        - Up another flight to the stone floor, and this is where the flour is actually made.
        - There are two pairs of stones here, each one four feet across. The bottom one stays still and the top one turns.
        - They never actually touch. The gap is about the thickness of a sheet of paper, and setting it is the miller's whole skill.
        - Too close and the flour comes out hot and scorched. Too wide and you get coarse meal that nobody will buy.
        - The grain comes in through this hopper at the top, and this little wooden arm, which they call the damsel, shakes it down a few grains at a time.
        - [Smile] It's called the damsel, so the story goes, because it chatters all day and never stops.
        - The furrows cut into the stones carry the flour out to the edge, where it drops down a chute to the floor below.

        ## 6. The miller's day
        Shows: Presenter at the window, village in the distance.
        Says:
        - So what was it like to be the miller here?
        - Early starts, for one thing. The pond had to be full by six, and the grinding was done by midday before the water ran short.
        - Afternoons were for dressing the stones, which means recutting the grooves with a small pick, and for the accounts.
        - The miller was paid in kind, usually a sixteenth of whatever he ground, and that share was called the toll.
        - Which is why millers were never entirely trusted. Chaucer's miller had a golden thumb, and that was not a compliment.
        - The last miller here, by all accounts, was scrupulously honest, and also completely deaf, which he blamed on the wheel.

        ## 7. Heading home
        Shows: Back on the footbridge, the wheel turning behind.
        Says:
        - And that's the mill. Back in working order, grinding a little flour on open days, and making a very good noise while it does it.
        - If you'd like to visit, it opens on the first Sunday of every month from April to October, and the volunteers will happily talk you through all of it in more detail than I just did.
        - Take the valley path back to the village; it follows the leat most of the way and it's about twenty minutes at an easy pace.
        - [Look back at the wheel] I think I'll stay a few more minutes and just listen.
        - See you next time.
        """

    /// Plain text, so that format has a sample (plan 011).
    static let seasidePier = """
        The Seaside Pier

        The entrance
        This pier opened in 1899, and for a while it was the longest on the coast.
        [Gesture along the boards] It runs out nearly a third of a mile, so we'll take it slowly.

        Halfway out
        Every board under your feet was replaced in the 1990s, one plank at a time.
        If you look down through the gaps, you can see the tide coming in.

        The end of the pier
        And here we are. On a clear day you can see the lighthouse from here.
        That's the pier. Thanks for walking it with me.
        """

    /// A built-in sample: its stable ID, kept in `Script.sampleID`, and its text.
    struct Sample: Identifiable, Sendable {
        let id: String
        let text: String
    }

    /// The samples, in the order of the Scripts screen's Samples section (plan 011, decision 2).
    static let all: [Sample] = [
        Sample(id: "harbour-walk", text: harbourWalk),
        Sample(id: "weekend-loaf", text: weekendLoaf),
        Sample(id: "old-watermill", text: oldWatermill),
        Sample(id: "seaside-pier", text: seasidePier),
    ]
}
