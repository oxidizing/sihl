module Utils = {
  module Async = Sihl.Core.Async;

  let getDb = () => {
    let config =
      Sihl.Core.Config.Db.read()
      |> Sihl.Core.Error.Decco.stringifyResult
      |> Sihl.Core.Error.failIfError;
    config |> Main.Database.pool |> Sihl.Core.Db.Database.connect;
  };

  // TODO make sure caller catches all errors
  let cleanDb = () => {
    let%Async db = getDb();
    Async.async @@ Belt.List.map(App.Database.clean, f => f(db));
  };
};

open Jest;

describe("Expect", () => {
  Expect.(test("toBe", () =>
            expect(1 + 2) |> toBe(3)
          ))
});

describe("Expect.Operators", () => {
  open Expect;
  open! Expect.Operators;

  test("==", () =>
    expect(1 + 2) === 3
  );
});
