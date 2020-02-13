module Async = Sihl.Core.Async;

module GetUsers = {
  [@decco]
  type users = list(Model.User.t);

  let endpoint = database =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: "/",
      handler: (conn, req) => {
        let%Async users = Repository.User.GetAll.query(conn);
        let response =
          users |> Repository.Repo.RepoResult.rows |> users_encode;
        Async.async @@ Sihl.Core.Http.Endpoint.OkJson(response);
      },
    });
};

module GetUser = {
  [@decco]
  type params = {userId: string};

  let endpoint = database =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: "/:id/",
      handler: (conn, req) => {
        let%Async {userId} = req.requireParams(params_decode);
        let%Async user = Repository.User.Get.query(conn, ~userId);
        let response = user |> Model.User.t_encode;
        Async.async @@ Sihl.Core.Http.Endpoint.OkJson(response);
      },
    });
};

module GetMe = {
  type params = {userId: string};

  let endpoint = database =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: "/me/",
      handler: (conn, req) => {
        let%Async header = req.requireHeader("authorization");
        let tokenString =
          header |> Model.Token.fromHeader |> Belt.Option.getExn;
        let%Async token = Repository.Token.Get.query(conn, ~tokenString);
        let%Async user =
          Repository.User.Get.query(conn, ~userId=token.userId);
        let response = user |> Model.User.t_encode;
        Async.async @@ Sihl.Core.Http.Endpoint.OkJson(response);
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

  let endpoint = database =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: "/login/",
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async {email, password} = req.requireQuery(query_decode);
        let%Async user = Repository.User.GetByEmail.query(conn, ~email);
        if (!Sihl.Core.Bcrypt.Hash.compareSync(password, user.password)) {
          abort @@ Unauthorized("Invalid password or email provided");
        };
        let token = Model.Token.generate(~user);
        let%Async _ = Repository.Token.Store.query(conn, ~token);
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

  let endpoint = database =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: "/login/",
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async {email, username, password, givenName, familyName, phone} =
          req.requireBody(body_in_decode);
        let user =
          abortIfError(
            Model.User.make(
              ~email,
              ~username,
              ~password,
              ~givenName,
              ~familyName,
              ~phone,
            ),
          );
        let%Async _ = Repository.User.Store.query(conn, ~user);
        Async.async @@ OkJson(body_out_encode({message: "ok"}));
      },
    });
};

// TODO
// POST /request-password-reset/
// POST /reset-password/
// POST /update-password/
// POST /set-password/
