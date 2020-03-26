// TODO this is just so we can instantiate the App module to test some pure functions
// In the future we might plug in some in-memory database to properly test everything
module TestPersistence = {
  module Connection = {
    let release = _ => ();
    let query = (_, ~stmt as _, ~parameters as _) =>
      Js.Promise.resolve(Belt.Result.Error("Not implemented"));
    let querySimple = (_, ~stmt as _, ~parameters as _) =>
      Js.Promise.resolve(Belt.Result.Error("Not implemented"));
    let execute = (_, ~stmt as _, ~parameters as _) =>
      Js.Promise.resolve(Belt.Result.Error("Not implemented"));
    let executeSimple = (_, ~stmt as _, ~parameters as _) =>
      Js.Promise.resolve(Belt.Result.Error("Not implemented"));
  };
  module Database = {
    type t;
    let setup = [%raw {| function() { return ""; } |}];
    let end_ = [%raw {| function() { return ""; } |}];
    let connect = [%raw {| function() { return ""; } |}];
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
    let setupMigrationStorage = _ => Js.Promise.resolve();
    let getMigrationStatus = (_, ~namespace as _) =>
      Js.Promise.resolve(Belt.Result.Error("Not impelemted"));
    let hasMigrationStatus = (_, ~namespace as _) =>
      Js.Promise.resolve(true);
    let upsertMigrationStatus = (_, ~status as _) => Js.Promise.resolve();
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
