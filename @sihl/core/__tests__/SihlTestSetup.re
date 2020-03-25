module TestPersistence = {
  let release = _ => ();
  let query = (_, ~stmt, ~parameters) =>
    Js.Promise.resolve(Belt.Result.Error("Not implemented"));
  let execute = (_, ~stmt, ~parameters) =>
    Js.Promise.resolve(Belt.Result.Error("Not implemented"));
  let setup: SihlCoreDbCore.Config.t => SihlCoreDbCore.Database.t = [%raw
    {| function() { return ""; } |}
  ];
  let end_: SihlCoreDbCore.Database.t => unit = [%raw
    {| function() { return ""; } |}
  ];
  let connect:
    SihlCoreDbCore.Database.t => Js.Promise.t(SihlCoreDbCore.Connection.t) = [%raw
    {| function() { return ""; } |}
  ];
};

module Persistence = SihlCoreDbCore.Make(TestPersistence);

module Core = SihlCore;
module App = SihlCore.Make(Persistence);

open Jest;
open Expect;

describe("Setup", () => {
  test("all good", () => {
    true |> expect |> toEqual(true)
  })
});
