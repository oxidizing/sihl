module Common = SihlCore.Common;
module App = SihlCore.App;

open Jest;
open Expect;

describe("Setup", () => {
  test("all good", () => {
    true |> expect |> toEqual(true)
  })
});
