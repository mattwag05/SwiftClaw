/// Pad a string to a fixed width for tabular CLI output.
func col(_ s: String, _ w: Int) -> String {
    s.padding(toLength: w, withPad: " ", startingAt: 0)
}
