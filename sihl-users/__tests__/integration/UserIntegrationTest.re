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
    ->Belt.List.map(Sihl.Core.Db.Repo.execute(conn))
    ->Async.allInOrder
    ->Async.mapAsync(_ => releaseConnection(conn));
  };
};

open Jest;

module Async = Sihl.Core.Async;

// TODO move global state like db connection and app to global module
beforeAllPromise(_ => {
  let%Async _ = Utils.runMigrations();
  Async.async(App.Server.start());
});

beforeEachPromise(Utils.cleanData);

describe("User can't login with wrong credentials", () => {
  // TODO
  // 1. /login/
  Expect.(
    testPromise("promise", () => Async.async(expect(1 + 2) |> toBe(3)))
  )
});

describe("User registers and gets own user", () => {
  // TODO
  // 1. /register/
  // 2. /login/ as user
  // 2. /me/
  Expect.(
    testPromise("promise", () => Async.async(expect(1 + 2) |> toBe(3)))
  )
});

describe("User can't fetch all users", () => {
  // TODO
  // 1. /register/
  // 2. /login/ as user
  // 3. /users/ fails
  Expect.(
    testPromise("promise", () => Async.async(expect(1 + 2) |> toBe(3)))
  )
});

describe("Admin fetches all users", () => {
  // TODO
  // 1. /register/
  // 2. /login/ as admin
  // 3. /users/ as admin
  // 4. /user/:id/ as admin
  Expect.(
    testPromise("promise", () => Async.async(expect(1 + 2) |> toBe(3)))
  )
});
