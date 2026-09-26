//// Certainty bands.
////
//// The first Gleam module in this repository, and deliberately a modest one:
//// it classifies a certainty into a display band and nothing authoritative
//// depends on the answer. It exists to prove the toolchain end to end before
//// a kernel that matters is written in Gleam.
////
//// It is still a kernel by the estate's criteria -- pure, total, no I/O -- and
//// it shows the property the policy is actually about: `Band` has four
//// variants and the compiler will not let a `case` over it miss one.

/// Where a certainty sits, for presentation only.
pub type Band {
  Speculative
  Tentative
  Probable
  Confident
}

/// Certainty is constrained to [0.0, 1.0] by the Edge resource. A value
/// outside it is reported rather than clamped: silently rounding a bad number
/// into a good-looking band is how a defect becomes invisible.
pub type Classification {
  Classified(band: Band)
  OutOfRange(value: Float)
}

pub fn classify(certainty: Float) -> Classification {
  case certainty <. 0.0 || certainty >. 1.0 {
    True -> OutOfRange(certainty)
    False -> Classified(band_of(certainty))
  }
}

fn band_of(certainty: Float) -> Band {
  case certainty {
    c if c <. 0.25 -> Speculative
    c if c <. 0.5 -> Tentative
    c if c <. 0.75 -> Probable
    _ -> Confident
  }
}
