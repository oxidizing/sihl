include Sihl.Core.Test;
Integration.setupHarness(App.app);
open Jest;

let baseUrl = "http://localhost:3000/users";
let adminBaseUrl = "http://localhost:3000/admin/users";

Expect.(
  testPromise("User creates board", () => {
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
    let%Async _ =
      Sihl.Core.Main.Manager.seed(
        Sihl.Users.Seeds.set,
        Sihl.Users.Seeds.Admin,
      );
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/register/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          (),
        ),
      );
    /* let%Async loginResponse = */
    /*   Fetch.fetch(baseUrl ++ "/login?email=foobar@example.com&password=123"); */
    /* let%Async tokenJson = Fetch.Response.json(loginResponse); */
    /* let Routes.Login.{token} = */
    /*   tokenJson |> Routes.Login.response_body_decode |> Belt.Result.getExn; */
    /* let%Async usersResponse = */
    /*   Fetch.fetchWithInit( */
    /*     baseUrl ++ "/users/me/", */
    /*     Fetch.RequestInit.make( */
    /*       ~method_=Get, */
    /*       ~headers= */
    /*         Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}), */
    /*       (), */
    /*     ), */
    /*   ); */
    /* let%Async usersJson = Fetch.Response.json(usersResponse); */
    /* let {Model.User.email} = */
    /*   usersJson |> Model.User.t_decode |> Belt.Result.getExn; */

    "" |> expect |> toBe("foobar@example.com") |> Sihl.Core.Async.async;
  })
);
