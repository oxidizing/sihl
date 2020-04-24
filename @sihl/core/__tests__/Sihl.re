module Core = SihlCore;

open Jest;
open Expect;

describe("Setup", () => {
  test("all good", () => {
    true |> expect |> toEqual(true)
  })
});
