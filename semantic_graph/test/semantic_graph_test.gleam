//// Entry point for the Gleam suite.
////
//// `mix gleam.test` calls `<app>_test.main/0`; gleeunit then discovers every
//// `*_test.gleam` module under test/. The tests themselves live beside the
//// kernel they cover.

import gleeunit

pub fn main() {
  gleeunit.main()
}
