module Async = Sihl.Core.Async;

module GetUsers = {
  [@decco]
  type users = list(Model.User.t);

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorization(req);
        let%Async user = Service.User.authenticate(conn, token);
        if (!Model.User.isAdmin(user)) {
          abort @@ Forbidden("Not allowed");
        };
        let%Async users = Service.User.getAll(conn);
        let response = users |> Sihl.Core.Db.Repo.Result.rows |> users_encode;
        Async.async @@ Sihl.Core.Http.Endpoint.OkJson(response);
      },
    });
};

module GetUser = {
  [@decco]
  type params = {userId: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/:id/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async header = req.requireHeader("authorization");
        let%Async user = Service.User.authenticate(conn, header);
        let%Async {userId} = req.requireParams(params_decode);
        if (!Model.User.isAdmin(user) && userId !== user.id) {
          abort @@ Forbidden("Not allowed");
        };
        let%Async user =
          Repository.User.Get.query(conn, ~userId)
          |> abortIfErr(Forbidden("Not allowed"));
        let response = user |> Model.User.t_encode;
        Async.async @@ OkJson(response);
      },
    });
};

module GetMe = {
  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/me/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorization(req);
        let%Async user = Service.User.authenticate(conn, token);
        let response = user |> Model.User.t_encode;
        Async.async @@ OkJson(response);
      },
    });
};

module Login = {
  [@decco]
  type query = {
    email: string,
    password: string,
  };

  [@decco]
  type response_body = {token: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/login/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async {email, password} = req.requireQuery(query_decode);
        let%Async token = Service.User.login(conn, ~email, ~password);
        let response = {token: token.token} |> response_body_encode;
        Async.async @@ OkJson(response);
      },
    });
};

module Register = {
  [@decco]
  type body_in = {
    email: string,
    username: string,
    password: string,
    givenName: string,
    familyName: string,
    phone: option(string),
  };

  [@decco]
  type body_out = {message: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/register/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async {email, username, password, givenName, familyName, phone} =
          req.requireBody(body_in_decode);
        let%Async _ =
          Service.User.register(
            conn,
            ~email,
            ~username,
            ~password,
            ~givenName,
            ~familyName,
            ~phone,
          );
        Async.async @@ OkJson(body_out_encode({message: "ok"}));
      },
    });
};

// TODO
// POST /request-password-reset/
// POST /reset-password/
// POST /update-password/
// POST /set-password/
