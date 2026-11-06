/// Made-up scripts for the parser and import tests. The repo is public: never a real one.
enum Fixtures {

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
