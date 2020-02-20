[%raw "require('isomorphic-fetch')"];
open Jest;
module Async = Sihl.Core.Async;

// TODO move state to global module
module State = {
  let app = ref(None);
};

let seed = (app, seed) => {
  let db = Belt.Option.getExn(app^) |> App.Server.db;
  Seeds.set(db, seed);
};

beforeAllPromise(_ => {
  State.app := Some(App.Server.start());
  let app = State.app^ |> Belt.Option.getExn;
  app
  |> App.Server.db
  |> Sihl.Core.Db.Database.runMigrations(
       App.Settings.namespace,
       App.Database.migrations,
     );
});

beforeEachPromise(_ => {
  let app = State.app^ |> Belt.Option.getExn;
  app |> App.Server.db |> Sihl.Core.Db.Database.clean(App.Database.clean);
});

afterAllPromise(_ => {
  switch (State.app^) {
  | Some(app) => App.Server.stop(app)
  | _ => Sihl.Core.Async.async()
  }
});

let baseUrl = "http://localhost:3000";

Expect.(
  testPromise("User registers, logs in and fetches own user", () => {
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
    let%Async _ = seed(State.app, Seeds.Admin);
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/users/register/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          (),
        ),
      );
    let%Async loginResponse =
      Fetch.fetch(
        baseUrl ++ "/users/login?email=foobar@example.com&password=123",
      );
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Routes.Login.{token} =
      tokenJson |> Routes.Login.response_body_decode |> Belt.Result.getExn;
    let%Async usersResponse =
      Fetch.fetchWithInit(
        baseUrl ++ "/users/me/",
        Fetch.RequestInit.make(
          ~method_=Get,
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );
    let%Async usersJson = Fetch.Response.json(usersResponse);
    let {Model.User.email} =
      usersJson |> Model.User.t_decode |> Belt.Result.getExn;

    email |> expect |> toBe("foobar@example.com") |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("User can't log in with wrong credentials", () => {
    let%Async _ = seed(State.app, Seeds.AdminOneUser);
    let%Async loginResponse =
      Fetch.fetch(
        baseUrl ++ "/users/login?email=foobar@example.com&password=321",
      );
    loginResponse
    |> Fetch.Response.status
    |> expect
    |> toBe(
         Sihl.Core.Http.Endpoint.Status.Unauthorized
         |> Sihl.Core.Http.Endpoint.Status.toInt,
       )
    |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("User can't fetch all users", () => {
    let%Async _ = seed(State.app, Seeds.AdminOneUser);
    let%Async loginResponse =
      Fetch.fetch(
        baseUrl ++ "/users/login?email=foobar@example.com&password=123",
      );
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Routes.Login.{token} =
      tokenJson |> Routes.Login.response_body_decode |> Belt.Result.getExn;

    let%Async usersResponse =
      Fetch.fetchWithInit(
        baseUrl ++ "/users/",
        Fetch.RequestInit.make(
          ~method_=Get,
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );
    Fetch.Response.status(usersResponse)
    |> expect
    |> toBe(
         Sihl.Core.Http.Endpoint.Status.toInt(
           Sihl.Core.Http.Endpoint.Status.Forbidden,
         ),
       )
    |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("Admin can fetch all users", () => {
    let%Async _ = seed(State.app, Seeds.AdminOneUser);
    let%Async loginResponse =
      Fetch.fetch(
        baseUrl ++ "/users/login?email=admin@example.com&password=password",
      );
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Routes.Login.{token} =
      tokenJson |> Routes.Login.response_body_decode |> Belt.Result.getExn;

    let%Async usersResponse =
      Fetch.fetchWithInit(
        baseUrl ++ "/users/",
        Fetch.RequestInit.make(
          ~method_=Get,
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );
    let%Async usersJson = Fetch.Response.json(usersResponse);
    let users =
      usersJson
      |> Routes.GetUsers.users_decode
      |> Belt.Result.getExn
      |> Belt.List.toArray;

    users |> expect |> toHaveLength(2) |> Sihl.Core.Async.async;
  })
);
