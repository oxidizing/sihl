[%raw "require('isomorphic-fetch')"];

module Utils = {
  module Async = Sihl.Core.Async;

  let cleanData = db => {
    Sihl.Core.Db.Database.withConnection(
      db,
      conn => {
        let%Async _ =
          Sihl.Core.Db.Repo.execute(conn, "SET FOREIGN_KEY_CHECKS = 0;");
        let%Async _ =
          App.Database.clean->Belt.List.map(f => f(conn))->Async.allInOrder;
        Sihl.Core.Db.Repo.execute(conn, "SET FOREIGN_KEY_CHECKS = 1;");
      },
    );
  };

  let runMigrations = db => {
    Sihl.Core.Db.Database.withConnection(db, conn => {
      App.Settings.namespace
      ->App.Database.migrations
      ->Belt.List.map(Sihl.Core.Db.Repo.execute(conn))
      ->Async.allInOrder
    });
  };
};

open Jest;

module Async = Sihl.Core.Async;

// TODO move global state like db connection and app to global module
module State = {
  let app = ref(None);
};

beforeAllPromise(_ => {
  State.app := Some(App.Server.start());
  (State.app^)
  ->Belt.Option.map(App.Server.db)
  ->Belt.Option.map(Utils.runMigrations)
  ->Belt.Option.getWithDefault(Async.async());
});

beforeEachPromise(_ =>
  (State.app^)
  ->Belt.Option.map(App.Server.db)
  ->Belt.Option.map(Utils.cleanData)
  ->Belt.Option.getWithDefault(Async.async())
);

afterAllPromise(_ =>
  switch (State.app^) {
  | Some(app) => App.Server.stop(app)
  | _ => Sihl.Core.Async.async()
  }
);

Expect.(
  testPromise("User can register", () => {
    let body = {|
{
  "email": "foobar@example.com",
  "username": "foobar",
  "password": "123",
  "givenName": "Foo",
  "familyName": "Bar",
  "phone": "123"
}
|};
    Fetch.fetchWithInit(
      "http://localhost:3000/api/register/",
      Fetch.RequestInit.make(
        ~method_=Post,
        ~body=Fetch.BodyInit.make(body),
        (),
      ),
    )
    |> Js.Promise.then_(Fetch.Response.json)
    |> Js.Promise.then_(json =>
         json
         |> Js.Json.stringify
         |> expect
         |> toBe({|{"message":"ok"}|})
         |> Sihl.Core.Async.async
       );
  })
);

/* describe("User registers and gets own user", () => { */
/*   // TODO */
/*   // 1. /register/ */
/*   // 2. /login/ as user */
/*   // 2. /me/ */
/*   Expect.( */
/*     testPromise("promise", () => Async.async(expect(1 + 2) |> toBe(3))) */
/*   ) */
/* }); */

/* describe("User can't fetch all users", () => { */
/*   // TODO */
/*   // 1. /register/ */
/*   // 2. /login/ as user */
/*   // 3. /users/ fails */
/*   Expect.( */
/*     testPromise("promise", () => Async.async(expect(1 + 2) |> toBe(3))) */
/*   ) */
/* }); */

/* describe("Admin fetches all users", () => { */
/*   // TODO */
/*   // 1. /register/ */
/*   // 2. /login/ as admin */
/*   // 3. /users/ as admin */
/*   // 4. /user/:id/ as admin */
/*   Expect.( */
/*     testPromise("promise", () => Async.async(expect(1 + 2) |> toBe(3))) */
/*   ) */
/* }); */
