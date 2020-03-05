module Async = Sihl.Core.Async;

module GetBoardsByUser = {
  [@decco]
  type body_out = list(Model.Board.t);

  [@decco]
  type params = {userId: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/users/:userId/boards/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorizationToken(req);
        let%Async user = Sihl.Users.User.authenticate(conn, token);
        let%Async {userId} = req.requireParams(params_decode);
        let%Async boards = Service.Board.getAllByUser((conn, user), ~userId);
        let response =
          boards |> Sihl.Core.Db.Repo.Result.rows |> body_out_encode;
        Async.async @@ Sihl.Core.Http.Endpoint.OkJson(response);
      },
    });
};

module GetIssuesByBoard = {
  [@decco]
  type body_out = list(Model.Issue.t);

  [@decco]
  type params = {boardId: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/boards/:boardId/issues/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorizationToken(req);
        let%Async user = Sihl.Users.User.authenticate(conn, token);
        let%Async {boardId} = req.requireParams(params_decode);
        let%Async issues =
          Service.Issue.getAllByBoard((conn, user), ~boardId);
        let response =
          issues |> Sihl.Core.Db.Repo.Result.rows |> body_out_encode;
        Async.async @@ Sihl.Core.Http.Endpoint.OkJson(response);
      },
    });
};

module AddBoard = {
  [@decco]
  type body_in = {title: string};
  [@decco]
  type body_out = {message: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/boards/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorizationToken(req);
        let%Async user = Sihl.Users.User.authenticate(conn, token);
        let%Async {title} = req.requireBody(body_in_decode);
        let%Async _ = Service.Board.create((conn, user), ~title);
        Async.async @@ OkJson(body_out_encode({message: "ok"}));
      },
    });
};

module AddIssue = {
  [@decco]
  type body_in = {
    title: string,
    description: option(string),
    board: string,
  };
  [@decco]
  type body_out = {message: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/issues/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorizationToken(req);
        let%Async user = Sihl.Users.User.authenticate(conn, token);
        let%Async {title, description, board} =
          req.requireBody(body_in_decode);
        let%Async _ =
          Service.Issue.create((conn, user), ~title, ~description, ~board);
        Async.async @@ OkJson(body_out_encode({message: "ok"}));
      },
    });
};

module AdminUi = {
  module Issues = {
    let endpoint = (root, database) =>
      Sihl.Core.Http.dbEndpoint({
        database,
        verb: GET,
        path: {j|/admin/$root/issues/|j},
        handler: (conn, req) => {
          open! Sihl.Core.Http.Endpoint;
          let%Async token =
            Sihl.Core.Http.requireSessionCookie(req, "/admin/login/");
          let%Async user = Sihl.Users.User.authenticate(conn, token);
          let%Async issues = Service.Issue.getAll((conn, user));
          let issues = issues |> Sihl.Core.Db.Repo.Result.rows;
          Async.async @@
          OkHtml(Sihl.Users.AdminUi.render(<AdminUi.Issues issues />));
        },
      });
  };

  module Boards = {
    let endpoint = (root, database) =>
      Sihl.Core.Http.dbEndpoint({
        database,
        verb: GET,
        path: {j|/admin/$root/boards/|j},
        handler: (conn, req) => {
          open! Sihl.Core.Http.Endpoint;
          let%Async token =
            Sihl.Core.Http.requireSessionCookie(req, "/admin/login/");
          let%Async user = Sihl.Users.User.authenticate(conn, token);
          let%Async boards = Service.Board.getAll((conn, user));
          let boards = boards |> Sihl.Core.Db.Repo.Result.rows;
          Async.async @@
          OkHtml(Sihl.Users.AdminUi.render(<AdminUi.Boards boards />));
        },
      });
  };
};
