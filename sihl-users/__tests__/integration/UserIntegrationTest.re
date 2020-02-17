[%raw "require('isomorphic-fetch')"];
open Jest;
module Async = Sihl.Core.Async;

// TODO move state to global module
module State = {
  let app = ref(None);
};

beforeAllPromise(_ => {
  // TODO Create admin
  State.app := Some(App.Server.start());
  (State.app^)
  ->Belt.Option.map(App.Server.db)
  ->Belt.Option.map(
      Sihl.Core.Db.Database.runMigrations(
        App.Settings.namespace,
        App.Database.migrations,
      ),
    )
  ->Belt.Option.getWithDefault(Async.async());
});

beforeEachPromise(_ =>
  (State.app^)
  ->Belt.Option.map(App.Server.db)
  ->Belt.Option.map(Sihl.Core.Db.Database.clean(App.Database.clean))
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
    let%Async response =
      Fetch.fetchWithInit(
        "http://localhost:3000/api/register/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          (),
        ),
      );
    let%Async json = Fetch.Response.json(response);
    json
    |> Js.Json.stringify
    |> expect
    |> toBe({|{"message":"ok"}|})
    |> Sihl.Core.Async.async;
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
