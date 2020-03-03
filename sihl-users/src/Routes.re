module Async = Sihl.Core.Async;

module GetUsers = {
  [@decco]
  type users = list(Model.User.t);

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/users/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorizationToken(req);
        let%Async user = Service.User.authenticate(conn, token);
        let%Async users = Service.User.getAll((conn, user));
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
      path: {j|/$root/users/:id/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async header = req.requireHeader("authorization");
        let%Async user = Service.User.authenticate(conn, header);
        let%Async {userId} = req.requireParams(params_decode);
        let%Async user =
          Service.User.get((conn, user), ~userId)
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
      path: {j|/$root/users/me/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorizationToken(req);
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
    cookie: option(string),
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
        let%Async {email, password, cookie} = req.requireQuery(query_decode);
        let%Async (_, token) = Service.User.login(conn, ~email, ~password);
        switch (cookie) {
        | None =>
          let response = {token: token.token} |> response_body_encode;
          Async.async @@ OkJson(response);
        | Some(_) =>
          let headers =
            [Model.Token.setCookieHeader(token.token)] |> Js.Dict.fromList;
          Async.async @@ OkHeaders(headers);
        };
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
            (),
          );
        Async.async @@ OkJson(body_out_encode({message: "ok"}));
      },
    });
};

module ConfirmEmail = {
  [@decco]
  type query = {token: string};

  [@decco]
  type response_body = {message: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/confirm-email/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async {token} = req.requireQuery(query_decode);
        let%Async _ = Service.User.confirmEmail(conn, ~token);
        let response = {message: "Email confirmed"} |> response_body_encode;
        Async.async @@ OkJson(response);
      },
    });
};

module RequestPasswordReset = {
  [@decco]
  type body_in = {email: string};

  [@decco]
  type body_out = {message: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/request-password-reset/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async {email} = req.requireBody(body_in_decode);
        let%Async _ = Service.User.requestPasswordReset(conn, ~email);
        Async.async @@ OkJson(body_out_encode({message: "ok"}));
      },
    });
};

module ResetPassword = {
  [@decco]
  type body_in = {
    token: string,
    newPassword: string,
  };

  [@decco]
  type body_out = {message: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/reset-password/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async {token, newPassword} = req.requireBody(body_in_decode);
        let%Async _ = Service.User.resetPassword(conn, ~token, ~newPassword);
        Async.async @@ OkJson(body_out_encode({message: "ok"}));
      },
    });
};

module UpdatePassword = {
  [@decco]
  type body_in = {
    userId: string,
    currentPassword: string,
    newPassword: string,
  };

  [@decco]
  type body_out = {message: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/update-password/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorizationToken(req);
        let%Async user = Service.User.authenticate(conn, token);
        let%Async {userId, currentPassword, newPassword} =
          req.requireBody(body_in_decode);
        let%Async _ =
          Service.User.updatePassword(
            (conn, user),
            ~userId,
            ~currentPassword,
            ~newPassword,
          );
        Async.async @@ OkJson(body_out_encode({message: "ok"}));
      },
    });
};

module SetPassword = {
  [@decco]
  type body_in = {
    userId: string,
    newPassword: string,
  };

  [@decco]
  type body_out = {message: string};

  let endpoint = (root, database) =>
    Sihl.Core.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/set-password/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorizationToken(req);
        let%Async user = Service.User.authenticate(conn, token);
        let%Async {userId, newPassword} = req.requireBody(body_in_decode);
        let%Async _ =
          Service.User.setPassword((conn, user), ~userId, ~newPassword);
        Async.async @@ OkJson(body_out_encode({message: "ok"}));
      },
    });
};

module UpdateUserDetails = {
  [@decco]
  type body_in = {
    userId: string,
    email: string,
    username: string,
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
      path: {j|/$root/update-user-details/|j},
      handler: (conn, req) => {
        open! Sihl.Core.Http.Endpoint;
        let%Async token = Sihl.Core.Http.requireAuthorizationToken(req);
        let%Async user = Service.User.authenticate(conn, token);
        let%Async {userId, email, username, givenName, familyName, phone} =
          req.requireBody(body_in_decode);
        let%Async _ =
          Service.User.updateDetails(
            (conn, user),
            ~userId,
            ~email,
            ~username,
            ~givenName,
            ~familyName,
            ~phone,
          );
        Async.async @@ OkJson(body_out_encode({message: "ok"}));
      },
    });
};

module AdminUi = {
  module Dashboard = {
    [@decco]
    type query = {session: option(string)};

    let endpoint = (_, database) =>
      Sihl.Core.Http.dbEndpoint({
        database,
        verb: GET,
        path: {j|/admin/|j},
        handler: (conn, req) => {
          open! Sihl.Core.Http.Endpoint;
          let%Async {session} = req.requireQuery(query_decode);
          switch (session) {
          | None =>
            let%Async token =
              Sihl.Core.Http.requireSessionCookie(req, "/admin/login/");
            let%Async user = Service.User.authenticate(conn, token);
            if (!Model.User.isAdmin(user)) {
              abort @@ Unauthorized("User is not an admin");
            };
            Async.async @@
            OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.Dashboard user />));
          | Some(token) =>
            let%Async user = Service.User.authenticate(conn, token);
            if (!Model.User.isAdmin(user)) {
              abort @@ Unauthorized("User is not an admin");
            };
            let headers =
              [Model.Token.setCookieHeader(token)] |> Js.Dict.fromList;
            Async.async @@
            OkHtmlWithHeaders(
              AdminUi.HtmlTemplate.render(<AdminUi.Dashboard user />),
              headers,
            );
          };
        },
      });
  };

  module Login = {
    [@decco]
    type query = {
      email: option(string),
      password: option(string),
    };

    let endpoint = (_, database) =>
      Sihl.Core.Http.dbEndpoint({
        database,
        verb: GET,
        path: {j|/admin/login/|j},
        handler: (conn, req) => {
          open! Sihl.Core.Http.Endpoint;
          let%Async token = Sihl.Core.Http.sessionCookie(req);
          switch (token) {
          | Some(token) =>
            Async.async @@ FoundRedirect("/admin?session=" ++ token)
          | None =>
            let%Async {email, password} = req.requireQuery(query_decode);
            switch (email, password) {
            | (Some(email), Some(password)) =>
              let%Async (user, token) =
                Service.User.login(conn, ~email, ~password);
              if (!Model.User.isAdmin(user)) {
                abort @@ Unauthorized("User is not an admin");
              };
              Async.async @@ FoundRedirect("/admin?session=" ++ token.token);
            | _ =>
              Async.async @@
              OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.Login />))
            };
          };
        },
      });
  };

  module User = {
    [@decco]
    type params = {userId: string};

    let endpoint = (root, database) =>
      Sihl.Core.Http.dbEndpoint({
        database,
        verb: GET,
        path: {j|/admin/$root/users/:userId/|j},
        handler: (conn, req) => {
          open! Sihl.Core.Http.Endpoint;
          let%Async token =
            Sihl.Core.Http.requireSessionCookie(req, "/admin/login/");
          let%Async user = Service.User.authenticate(conn, token);
          let%Async {userId} = req.requireParams(params_decode);
          let%Async user =
            Service.User.get((conn, user), ~userId)
            |> abortIfErr(NotFound("User not found"));
          Async.async @@
          OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.User user />));
        },
      });
  };

  module Users = {
    let endpoint = (root, database) =>
      Sihl.Core.Http.dbEndpoint({
        database,
        verb: GET,
        path: {j|/admin/$root/users/|j},
        handler: (conn, req) => {
          open! Sihl.Core.Http.Endpoint;
          let%Async token =
            Sihl.Core.Http.requireSessionCookie(req, "/admin/login/");
          let%Async user = Service.User.authenticate(conn, token);
          let%Async users = Service.User.getAll((conn, user));
          let users = users |> Sihl.Core.Db.Repo.Result.rows;
          Async.async @@
          OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.Users users />));
        },
      });
  };
};
