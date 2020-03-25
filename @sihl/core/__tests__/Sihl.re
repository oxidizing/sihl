module TestDatabase = {
  let release = _ => ();
  let query = (_, ~stmt as _, ~parameters as _) =>
    Js.Promise.resolve(Belt.Result.Error("Not implemented"));
  let execute = (_, ~stmt as _, ~parameters as _) =>
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

module Core = Api.Core;
module App = Api.MakeApp(TestDatabase);

open Jest;
open Expect;

describe("Setup", () => {
  test("all good", () => {
    true |> expect |> toEqual(true)
  })
});
