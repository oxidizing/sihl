module Utils = {
  module Async = Sihl.Core.Async;

  let getConnection = () => {
    Sihl.Core.Config.Db.read()
    |> Sihl.Core.Error.Decco.stringifyResult
    |> Sihl.Core.Error.failIfError
    |> App.Database.database
    |> Sihl.Core.Db.Database.connect;
  };

  let releaseConnection = conn => {
    Sihl.Core.Db.Connection.release(conn);
  };

  let cleanData = () => {
    let%Async conn = getConnection();
    App.Database.clean
    ->Belt.List.map(f => f(conn))
    ->Async.allInOrder
    ->Async.mapAsync(_ => releaseConnection(conn));
  };

  let runMigrations = () => {
    let%Async conn = getConnection();
    App.Settings.namespace
    ->App.Database.migrations
    ->Belt.List.map(Repository.Repo.execute(conn))
    ->Async.allInOrder
    ->Async.mapAsync(_ => releaseConnection(conn));
  };
};

open Jest;

module Async = Sihl.Core.Async;

beforeAllPromise(_ => {
  let%Async _ = Utils.runMigrations();
  Async.async(App.Server.start());
});

beforeEachPromise(_ => Utils.cleanData());

describe("Expect", () => {
  Expect.(test("promise", () =>
            expect(1 + 2) |> toBe(3)
          ))
});

/* describe("Expect", () => { */
/*   Expect.(test("toBe", () => */
/*             expect(1 + 2) |> toBe(3) */
/*           )) */
/* }); */

/* describe("Expect.Operators", () => { */
/*   open Expect; */
/*   open! Expect.Operators; */

/*   test("==", () => */
/*     expect(1 + 2) === 3 */
/*   ); */
/* }); */
