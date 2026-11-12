import AVFoundation
@testable import Earwig

/// Made-up scripts for the parser and import tests. The repo is public: never a real one.
enum Fixtures {

    /// The parser and import tests' main fixture (plan 002, decision 12): the Harbour Walk in
    /// Cutaway's format, as the sample was until plan 015 (decision 13) wrote it in the documented one.
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

    /// Cutaway's own example from its file contract, with a source span and an `Open:` field.
    static let rosie = """
        # Script: Rosie's Walk

        ## 3. Rosie up ahead
        Shows: Rosie trots far ahead up the long track across the fields
        Footage: 0004 18.0-26.0
        Says:
        - Rosie's off up ahead, about 20 metres, sniffing away. (0005 28.2-41.0)
        - We follow the footpath down to the end of the fields.
        Open: two takes of this; which one?
        """

    /// The odd corners of the format: bold fields, other bullets, run-on lines, old `Notes:`,
    /// a line not understood, `Says: nothing`, a preamble and a step with no number.
    static let corners = """
        Draft for the autumn shoot.

        # The Allotment

        ## 1. At the gate
        **Shows:** The gate, the shed behind it,
          and the bean rows.
        **Says:**
        * Welcome to the allotment, where
          everything grows except what I planted.
        + It's been a wet year.
        A stray line nobody meant.
        Notes: check the light
          before noon

        ## Leaving
        Shows: Gate closing.
        Says: nothing

        ## 7. The compost
        Says: Inline lines count too.
        """

    static let plain = """
        The Ferry Crossing

        Boarding
        The ferry leaves at ten past the hour.
        - Find a seat on the left for the view.

        The crossing takes twenty minutes. [Look out to sea] On a good day you'll see dolphins.

        Arriving.
        That's the far shore.
        """
}

/// A silent buffer of a length, in the player's format, for the player and renderer tests.
func silence(seconds: TimeInterval) -> AVAudioPCMBuffer {
    let format = VoiceRenderer.outputFormat
    let frames = AVAudioFrameCount(max(seconds * format.sampleRate, 1))
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames
    return buffer
}
