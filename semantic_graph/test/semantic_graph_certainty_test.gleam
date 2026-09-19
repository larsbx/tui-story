import gleeunit/should
import semantic_graph_certainty.{
  Classified, Confident, OutOfRange, Probable, Speculative, Tentative,
}

pub fn classifies_each_band_test() {
  semantic_graph_certainty.classify(0.0)
  |> should.equal(Classified(Speculative))

  semantic_graph_certainty.classify(0.25)
  |> should.equal(Classified(Tentative))

  semantic_graph_certainty.classify(0.5)
  |> should.equal(Classified(Probable))

  semantic_graph_certainty.classify(1.0)
  |> should.equal(Classified(Confident))
}

pub fn reports_values_outside_the_range_test() {
  semantic_graph_certainty.classify(1.5)
  |> should.equal(OutOfRange(1.5))

  semantic_graph_certainty.classify(-0.2)
  |> should.equal(OutOfRange(-0.2))
}
