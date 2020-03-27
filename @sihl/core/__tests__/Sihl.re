// TODO this is just so we can instantiate the App module to test some pure functions
// In the future we might plug in some in-memory database to properly test everything
module TestPersistence = {
  module Connection = {
    type t;
    let release = _ => ();
    let raw = [%raw {| function() { return ""; } |}];
    let getMany = [%raw {| function() { return ""; } |}];
    let getOne = [%raw {| function() { return ""; } |}];
    let querySimple = [%raw {| function() { return ""; } |}];
    let execute = (_, ~stmt as _, ~parameters as _) =>
      Js.Promise.resolve(Belt.Result.Error("Not implemented"));
  };
  module Database = {
    type t;
    let setup = [%raw {| function() { return ""; } |}];
    let end_ = [%raw {| function() { return ""; } |}];
    let connect = [%raw {| function() { return ""; } |}];
    let withConnection = [%raw {| function() { return ""; } |}];
    let clean = [%raw {| function() { return ""; } |}];
  };
  module Migration = {
    module Status = {
      type t = unit;
      let make = (~namespace as _) => ();
      let version = _ => 0;
      let namespace = _ => "";
      let dirty = _ => false;
      let setVersion = (old, ~newVersion as _) => old;
      let t_decode = _ => Ok();
    };
    let setup = _ => [%raw {| function() { return ""; } |}];
    let get = [%raw {| function() { return ""; } |}];
    let has = [%raw {| function() { return ""; } |}];
    let upsert = [%raw {| function() { return ""; } |}];
  };
};

module Core = Api.Core;
module App = Api.MakeApp(TestPersistence);

open Jest;
open Expect;

describe("Setup", () => {
  test("all good", () => {
    true |> expect |> toEqual(true)
  })
});
