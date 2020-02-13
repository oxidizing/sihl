module Utils = {
  module Async = Sihl.Core.Async;

  let getConnection = () => {
    let config =
      Sihl.Core.Config.Db.read()
      |> Sihl.Core.Error.Decco.stringifyResult
      |> Sihl.Core.Error.failIfError;
    config |> App.Database.database |> Sihl.Core.Db.Database.connect;
  };

  // TODO make sure caller catches all errors
  let cleanDb = () => {
    let%Async conn = getConnection();
    Async.async @@ Belt.List.map(App.Database.clean, f => f(conn));
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
