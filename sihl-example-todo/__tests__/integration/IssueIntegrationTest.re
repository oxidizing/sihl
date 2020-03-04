include Sihl.Core.Test;
Integration.setupHarness(App.app);
open Jest;

let baseUrl = "http://localhost:3000/issues";

Expect.(
  testPromise("User creates board", () => {
    let body = {|{"title": "foobar"}|};
    let%Async _ =
      Sihl.Core.Main.Manager.seed(
        Sihl.Users.Seeds.set,
        Sihl.Users.Seeds.AdminOneUser,
      );
    let%Async loginResponse =
      Fetch.fetch(baseUrl ++ "/login?email=foobar@example.com&password=123");
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Sihl.Users.Routes.Login.{token} =
      tokenJson
      |> Sihl.Users.Routes.Login.response_body_decode
      |> Belt.Result.getExn;
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/boards/",
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
    let user = userJson |> Sihl.Users.User.fromJson |> Belt.Result.getExn;

    let%Async boardsResponse =
      Fetch.fetchWithInit(
        baseUrl ++ "/users/" ++ Sihl.Users.User.id(user) ++ "/boards/",
        Fetch.RequestInit.make(
          ~method_=Get,
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );
    let%Async boardsJson = Fetch.Response.json(boardsResponse);
    let boards =
      boardsJson |> Routes.GetBoardsByUser.boards_decode |> Belt.Result.getExn;

    let Model.Board.{title} = boards |> Belt.List.headExn;

    title |> expect |> toBe("foobar@example.com") |> Sihl.Core.Async.async;
  })
);
