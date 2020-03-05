include Sihl.Core.Test;
Integration.setupHarness([Sihl.Users.App.app([]), App.app()]);
open Jest;

let baseUrl = "http://localhost:3000";

Expect.(
  testPromise("User creates board", () => {
    let%Async user =
      Sihl.Core.Main.Manager.seed(
        Sihl.Users.Seeds.user("foobar@example.com", "123"),
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
    let body = {|{"title": "Board title"}|};
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
      boardsJson
      |> Routes.GetBoardsByUser.body_out_decode
      |> Belt.Result.getExn;

    let Model.Board.{title} = boards |> Belt.List.headExn;

    title |> expect |> toBe("Board title") |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("User creates issue for board", () => {
    let%Async user =
      Sihl.Core.Main.Manager.seed(
        Sihl.Users.Seeds.user("foobar@example.com", "123"),
      );
    let%Async board =
      Sihl.Core.Main.Manager.seed(Seeds.board(~user, ~title="Board title"));

    let%Async loginResponse =
      Fetch.fetch(
        baseUrl ++ "/users/login?email=foobar@example.com&password=123",
      );
    let%Async tokenJson = Fetch.Response.json(loginResponse);
    let Sihl.Users.Routes.Login.{token} =
      tokenJson
      |> Sihl.Users.Routes.Login.response_body_decode
      |> Belt.Result.getExn;
    let boardId = board.id;
    let body = {j|
       {
         "title": "Issue title",
         "description": "This is the description",
         "board": "$(boardId)"
       }
       |j};
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/issues/issues/",
        Fetch.RequestInit.make(
          ~method_=Post,
          ~body=Fetch.BodyInit.make(body),
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );

    let%Async issuesResponse =
      Fetch.fetchWithInit(
        baseUrl ++ "/issues/boards/" ++ board.id ++ "/issues/",
        Fetch.RequestInit.make(
          ~method_=Get,
          ~headers=
            Fetch.HeadersInit.make({"authorization": "Bearer " ++ token}),
          (),
        ),
      );
    let%Async issueJson = Fetch.Response.json(issuesResponse);
    let issues =
      issueJson
      |> Routes.GetIssuesByBoard.body_out_decode
      |> Belt.Result.getExn;

    let Model.Issue.{title} = issues |> Belt.List.headExn;

    title |> expect |> toBe("Issue title") |> Sihl.Core.Async.async;
  })
);
