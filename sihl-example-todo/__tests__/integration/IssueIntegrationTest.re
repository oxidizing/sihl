include Sihl.Core.Test;
Integration.setupHarness([Sihl.Users.App.app([]), App.app()]);
open Jest;

let baseUrl = "http://localhost:3000";

Expect.(
  testPromise("User creates board", () => {
    let body = {|{"title": "Board title"}|};
    let%Async _ =
      Sihl.Core.Main.Manager.seed(
        Sihl.Users.Seeds.set,
        Sihl.Users.Seeds.AdminOneUser,
      );
    let%Async loginResponse =
      Fetch.fetch(
        baseUrl ++ "/users/login?email=foobar@example.com&password=123",
      );
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Sihl.Users.Routes.Login.{token} =
      tokenJson
      |> Sihl.Users.Routes.Login.response_body_decode
      |> Belt.Result.getExn;
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/issues/boards/",
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
        baseUrl ++ "/users/users/me/",
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
        baseUrl ++ "/issues/users/" ++ Sihl.Users.User.id(user) ++ "/boards/",
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

    title |> expect |> toBe("Board title") |> Sihl.Core.Async.async;
  })
);

/* Expect.( */
/*   testPromise("User creates issue for board", () => { */
/*     let boardId = ""; */
/*     let body = {j| */
       /* { */
       /*   "title": "Issue title", */
       /*   "description": "This is the description", */
       /*   "board": "$(boardId)" */
       /* } */
       /* |j}; */
/*     let%Async _ = */
/*       Sihl.Core.Main.Manager.seed( */
/*         Sihl.Users.Seeds.set, */
/*         Sihl.Users.Seeds.AdminOneUser, */
/*       ); */
/*     let%Async loginResponse = */
/*       Fetch.fetch( */
/*         baseUrl ++ "/users/login?email=foobar@example.com&password=123", */
/*       ); */
/*     let%Async tokenJson = Fetch.Response.json(loginResponse); */
/*     let Sihl.Users.Routes.Login.{token} = */
/*       tokenJson */
/*       |> Sihl.Users.Routes.Login.response_body_decode */
/*       |> Belt.Result.getExn; */
/*     let%Async _ = */
/*       Fetch.fetchWithInit( */
/*         baseUrl ++ "/issues/boards/", */
/*         Fetch.RequestInit.make( */
/*           ~method_=Post, */
/*           ~body=Fetch.BodyInit.make(body), */
/*           ~headers= */
/*             Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}), */
/*           (), */
/*         ), */
/*       ); */
/*     let%Async userResponse = */
/*       Fetch.fetchWithInit( */
/*         baseUrl ++ "/users/users/me/", */
/*         Fetch.RequestInit.make( */
/*           ~method_=Get, */
/*           ~headers= */
/*             Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}), */
/*           (), */
/*         ), */
/*       ); */
/*     let%Async userJson = Fetch.Response.json(userResponse); */
/*     let user = userJson |> Sihl.Users.User.fromJson |> Belt.Result.getExn; */

/*     let%Async boardsResponse = */
/*       Fetch.fetchWithInit( */
/*         baseUrl ++ "/issues/users/" ++ Sihl.Users.User.id(user) ++ "/boards/", */
/*         Fetch.RequestInit.make( */
/*           ~method_=Get, */
/*           ~headers= */
/*             Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}), */
/*           (), */
/*         ), */
/*       ); */
/*     let%Async boardsJson = Fetch.Response.json(boardsResponse); */
/*     let boards = */
/*       boardsJson |> Routes.GetBoardsByUser.boards_decode |> Belt.Result.getExn; */

/*     let Model.Board.{title} = boards |> Belt.List.headExn; */

/*     title |> expect |> toBe("foobar") |> Sihl.Core.Async.async; */
/*   }) */
/* ); */
