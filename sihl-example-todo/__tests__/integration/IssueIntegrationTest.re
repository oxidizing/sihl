include Sihl.Core.Test;
Integration.setupHarness([Sihl.Users.App.app([]), App.app()]);
open Jest;

let baseUrl = "http://localhost:3000";

Expect.(
  testPromise("User creates board", () => {
    let%Async (user, {token}) =
      Sihl.Core.Main.Manager.seed(
        Sihl.Users.Seeds.loggedInUser("foobar@example.com", "123"),
      );
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
    let%Async (user, {token}) =
      Sihl.Core.Main.Manager.seed(
        Sihl.Users.Seeds.loggedInUser("foobar@example.com", "123"),
      );
    let%Async board =
      Sihl.Core.Main.Manager.seed(Seeds.board(~user, ~title="Board title"));

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

Expect.(
  testPromise("User fetches issues of board", () => {
    let%Async (user, {token}) =
      Sihl.Core.Main.Manager.seed(
        Sihl.Users.Seeds.loggedInUser("foobar@example.com", "123"),
      );
    let%Async board1 =
      Sihl.Core.Main.Manager.seed(Seeds.board(~user, ~title="board 1"));
    let%Async board2 =
      Sihl.Core.Main.Manager.seed(Seeds.board(~user, ~title="board 2"));
    let%Async _ =
      Sihl.Core.Main.Manager.seed(
        Seeds.issue(
          ~board=board1.id,
          ~user,
          ~title="issue",
          ~description=None,
        ),
      );
    let%Async issuesResponse =
      Fetch.fetchWithInit(
        baseUrl ++ "/issues/boards/" ++ board2.id ++ "/issues/",
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
      |> Belt.Result.getExn
      |> Belt.List.toArray;
    issues |> expect |> toHaveLength(0) |> Sihl.Core.Async.async;
  })
);

Expect.(
  testPromise("User commpletes issue", () => {
    let%Async (user, {token}) =
      Sihl.Core.Main.Manager.seed(
        Sihl.Users.Seeds.loggedInUser("foobar@example.com", "123"),
      );
    let%Async board =
      Sihl.Core.Main.Manager.seed(Seeds.board(~user, ~title="Board title"));
    let%Async issue =
      Sihl.Core.Main.Manager.seed(
        Seeds.issue(
          ~board=board.id,
          ~user,
          ~title="Issue title",
          ~description=None,
        ),
      );
    let%Async _ =
      Fetch.fetchWithInit(
        baseUrl ++ "/issues/issues/" ++ issue.id ++ "/complete/",
        Fetch.RequestInit.make(
          ~method_=Post,
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

    let Model.Issue.{status} = issues |> Belt.List.headExn;

    status |> expect |> toBe("completed") |> Sihl.Core.Async.async;
  })
);
