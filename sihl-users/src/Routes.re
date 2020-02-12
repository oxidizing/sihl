module Async = Sihl.Core.Async;

module GetUsers = {
  [@decco]
  type users = list(Model.User.t);

  let endpoint = database =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: "/",
      handler: (conn, _req) => {
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
      handler: (conn, _req) => {
        let%Async {userId} = _req.requireParams(params_decode);
        let%Async user = Repository.User.Get.query(conn, ~userId);
        let response = user |> Model.User.encode;
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
      handler: (conn, _req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async {email, password} = _req.requireQuery(query_decode);
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

/* let auth: Sihl.Core.Http.Middleware.t = */
/*   (handler, request) => { */
/*     open Tablecloth; */
/*     let isValidToken = */
/*       request */
/*       |> Sihl.Core.Http.Request.authToken */
/*       |> Option.map(~f=Sihl.Core.Jwt.isVerifyableToken(~secret="ABC")) */
/*       |> Option.withDefault(~default=false); */
/*     isValidToken */
/*       ? handler(request) */
/*       : Future.value( */
/*           Sihl.Core.Http.Response.errorToResponse( */
/*             `AuthenticationError("Not authenticated"), */
/*           ), */
/*         ); */
/*   }; */

/* Route.post("/register/", Routes.register), */
/* Route.get("/login/", Routes.login), */
/* Route.get("/", Routes.getUsers(pool) |> Routes.auth), */
/* Route.get("/:id/", Routes.getUser(pool) |> Routes.auth), */
/* Route.get("/me/", Routes.getMyUser |> Routes.auth), */
/* Route.post( */
/*   "/request-password-reset/", */
/*   Routes.requestPasswordReset |> Routes.auth, */
/* ), */
/* Route.post("/reset-password/", Routes.resetPassword |> Routes.auth), */
/* Route.post("/update-password/", Routes.updatePassword |> Routes.auth), */
/* Route.post("/set-password/", Routes.setPassword |> Routes.auth), */
