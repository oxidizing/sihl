include Sihl.App.Test;
Integration.setupHarness([App.app([])]);
open Jest;

let baseUrl = "http://localhost:3000/users";
let adminBaseUrl = "http://localhost:3000/admin/users";

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
    let%Async _ = Sihl.App.Main.Manager.seed(Seeds.admin);
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/register/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          (),
        ),
      );
    let%Async loginResponse =
      Fetch.fetch(baseUrl ++ "/login?email=foobar@example.com&password=123");
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Routes.Login.{token} =
      tokenJson |> Routes.Login.body_out_decode |> Belt.Result.getExn;
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
  testPromise("User registration for existing email fails", () => {
    let%Async _ =
      Sihl.App.Main.Manager.seed(Seeds.user("foobar@example.com", "123"));

    let body = {|
       {
         "email": "foobar@example.com",
         "username": "someothername",
         "password": "somepassword",
         "givenName": "Foo",
         "familyName": "Bar",
         "phone": "123"
       }
       |};
    let%Async response =
      Fetch.fetchWithInit(
        baseUrl ++ "/register/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          (),
        ),
      );

    response
    |> Fetch.Response.status
    |> expect
    |> toBe(400)
    |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("User can not fetch own user after logging out", () => {
    let%Async _ = Sihl.App.Main.Manager.seed(Seeds.admin);
    let%Async _ =
      Sihl.App.Main.Manager.seed(Seeds.user("foobar@example.com", "123"));

    let%Async loginResponse =
      Fetch.fetch(baseUrl ++ "/login?email=foobar@example.com&password=123");
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Routes.Login.{token} =
      tokenJson |> Routes.Login.body_out_decode |> Belt.Result.getExn;
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/logout/",
        Fetch.RequestInit.make(
          ~method_=Delete,
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );
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
    usersResponse
    |> Fetch.Response.status
    |> expect
    |> toBe(401)
    |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("User logs in, gets cookie and fetches own user", () => {
    let%Async _ = Sihl.App.Main.Manager.seed(Seeds.admin);
    let%Async user =
      Sihl.App.Main.Manager.seed(Seeds.user("foobar@example.com", "123"));
    let%Async loginResponse =
      Fetch.fetch(
        baseUrl ++ "/login?email=foobar@example.com&password=123&cookie=true",
      );
    let cookie =
      loginResponse
      |> Fetch.Response.headers
      |> Fetch.Headers.get("set-cookie");

    let%Async usersResponse =
      Fetch.fetchWithInit(
        adminBaseUrl ++ "/users/" ++ user.id,
        Fetch.RequestInit.make(
          ~method_=Get,
          ~headers=Fetch.HeadersInit.make({"cookie": cookie}),
          (),
        ),
      );

    usersResponse
    |> Fetch.Response.status
    |> expect
    |> toBe(200)
    |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("User registers and confirms mail", () => {
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
    let%Async _ = Sihl.App.Main.Manager.seed(Seeds.admin);
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/register/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          (),
        ),
      );
    let mail: Sihl.Core.Email.t =
      Sihl.Core.Email.getLastEmail() |> Belt.Option.getExn;
    let tokenRe = Js.Re.fromString("token\=(.*)");
    let token =
      Js.Re.exec_(tokenRe, mail.text)
      ->Belt.Option.getExn
      ->Js.Re.captures
      ->Belt.Array.get(1)
      ->Belt.Option.getExn
      ->Js.Nullable.toOption
      ->Belt.Option.getExn;

    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/confirm-email?token=" ++ token,
        Fetch.RequestInit.make(~method_=Get, ()),
      );

    let%Async loginResponse =
      Fetch.fetch(baseUrl ++ "/login?email=foobar@example.com&password=123");
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Routes.Login.{token} =
      tokenJson |> Routes.Login.body_out_decode |> Belt.Result.getExn;
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
    let {Model.User.confirmed} =
      usersJson |> Model.User.t_decode |> Belt.Result.getExn;

    confirmed |> expect |> toBe(true) |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("User can't log in with wrong credentials", () => {
    let%Async _ = Sihl.App.Main.Manager.seed(Seeds.admin);
    let%Async _ =
      Sihl.App.Main.Manager.seed(Seeds.user("foobar@example.com", "123"));
    let%Async loginResponse =
      Fetch.fetch(baseUrl ++ "/login?email=foobar@example.com&password=321");
    loginResponse
    |> Fetch.Response.status
    |> expect
    |> toBe(
         Sihl.App.Http.Endpoint.Status.Unauthorized
         |> Sihl.App.Http.Endpoint.Status.toInt,
       )
    |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("User resets password", () => {
    let%Async _ = Sihl.App.Main.Manager.seed(Seeds.admin);
    let%Async _ =
      Sihl.App.Main.Manager.seed(Seeds.user("foobar@example.com", "123"));
    let body = {|{"email": "foobar@example.com"}|};
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/request-password-reset/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          (),
        ),
      );

    let mail: Sihl.Core.Email.t =
      Sihl.Core.Email.getLastEmail() |> Belt.Option.getExn;
    let tokenRe = Js.Re.fromString("token\=(.*)");
    let token =
      Js.Re.exec_(tokenRe, mail.text)
      ->Belt.Option.getExn
      ->Js.Re.captures
      ->Belt.Array.get(1)
      ->Belt.Option.getExn
      ->Js.Nullable.toOption
      ->Belt.Option.getExn;

    let body = {j|{"token": "$(token)", "newPassword": "321"}|j};
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/reset-password/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          (),
        ),
      );
    let%Async loginResponse =
      Fetch.fetch(baseUrl ++ "/login?email=foobar@example.com&password=321");
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Routes.Login.{token} =
      tokenJson |> Routes.Login.body_out_decode |> Belt.Result.getExn;

    token |> expect |> toMatch(".*") |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("User updates password", () => {
    let%Async _ = Sihl.App.Main.Manager.seed(Seeds.admin);
    let%Async (user, {token}) =
      Sihl.App.Main.Manager.seed(
        Seeds.loggedInUser("foobar@example.com", "123"),
      );
    let userId = user.id;
    let body = {j|{"userId": "$(userId)", "currentPassword": "123", "newPassword": "321"}|j};
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/update-password/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );

    let%Async loginResponse =
      Fetch.fetch(baseUrl ++ "/login?email=foobar@example.com&password=321");
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Routes.Login.{token} =
      tokenJson |> Routes.Login.body_out_decode |> Belt.Result.getExn;

    token |> expect |> toMatch(".*") |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("User updates own details", () => {
    let%Async _ = Sihl.App.Main.Manager.seed(Seeds.admin);
    let%Async (user, {token}) =
      Sihl.App.Main.Manager.seed(
        Seeds.loggedInUser("foobar@example.com", "123"),
      );

    let userId = user.id;
    let body = {j|
{
  "userId": "$(userId)",
  "email": "updatedmail@example.com",
  "username": "foobar",
  "givenName": "Foo",
  "familyName": "Bar"
}
|j};
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/update-user-details/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );

    let%Async userResponse =
      Fetch.fetchWithInit(
        baseUrl ++ "/users/me/",
        Fetch.RequestInit.make(
          ~method_=Get,
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );
    let%Async userJson = Fetch.Response.json(userResponse);
    let user = userJson |> Model.User.t_decode |> Belt.Result.getExn;

    user.email
    |> expect
    |> toBe("updatedmail@example.com")
    |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("Admin sets password", () => {
    let%Async (_, {token}) =
      Sihl.App.Main.Manager.seed(Seeds.loggedInAdmin);
    let%Async user =
      Sihl.App.Main.Manager.seed(Seeds.user("foobar@example.com", "123"));
    let userId = user.id;
    let body = {j|{"userId": "$(userId)", "newPassword": "321"}|j};
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/set-password/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );

    let%Async loginResponse =
      Fetch.fetch(baseUrl ++ "/login?email=foobar@example.com&password=321");
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Routes.Login.{token} =
      tokenJson |> Routes.Login.body_out_decode |> Belt.Result.getExn;

    token |> expect |> toMatch(".*") |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("Admin can fetch all users", () => {
    let%Async (_, {token}) =
      Sihl.App.Main.Manager.seed(Seeds.loggedInAdmin);
    let%Async _ =
      Sihl.App.Main.Manager.seed(Seeds.user("foobar@example.com", "123"));
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
      |> Routes.GetUsers.body_out_decode
      |> Belt.Result.getExn
      |> Belt.List.toArray;

    users |> expect |> toHaveLength(2) |> Sihl.Core.Async.async;
  })
);
