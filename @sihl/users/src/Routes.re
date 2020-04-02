module Async = Sihl.Common.Async;

module GetUsers = {
  [@decco]
  type body_out = list(Model.User.t);

  let endpoint = (root, database) =>
    Sihl.App.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/users/|j},
      handler: (conn, req) => {
        open! Sihl.App.Http.Endpoint;
        let%Async token = Sihl.App.Http.requireAuthorizationToken(req);
        let%Async user = Service.User.authenticate(conn, token);
        let%Async users = Service.User.getAll((conn, user));
        let response =
          users |> Sihl.Common.Db.Result.Query.rows |> body_out_encode;
        Async.async @@ Sihl.App.Http.Endpoint.OkJson(response);
      },
    });
};

module GetUser = {
  [@decco]
  type params = {userId: string};

  let endpoint = (root, database) =>
    Sihl.App.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/users/:id/|j},
      handler: (conn, req) => {
        open! Sihl.App.Http.Endpoint;
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
    Sihl.App.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/users/me/|j},
      handler: (conn, req) => {
        open! Sihl.App.Http.Endpoint;
        let%Async token = Sihl.App.Http.requireAuthorizationToken(req);
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
  type body_out = {
    token: string,
    userId: string,
  };

  let endpoint = (root, database) =>
    Sihl.App.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/login/|j},
      handler: (conn, req) => {
        open! Sihl.App.Http.Endpoint;
        let%Async {email, password, cookie} = req.requireQuery(query_decode);
        let%Async (_, token) = Service.User.login(conn, ~email, ~password);
        let%Async user = Service.User.authenticate(conn, token.token);
        switch (cookie) {
        | None =>
          let response =
            {token: token.token, userId: user.id} |> body_out_encode;
          Async.async @@ OkJson(response);
        | Some(_) =>
          let headers =
            [Model.Token.setCookieHeader(token.token)] |> Js.Dict.fromList;
          Async.async @@ OkHeaders(headers);
        };
      },
    });
};

module Logout = {
  let endpoint = (root, database) =>
    Sihl.App.Http.dbEndpoint({
      database,
      verb: DELETE,
      path: {j|/$root/logout/|j},
      handler: (conn, req) => {
        open! Sihl.App.Http.Endpoint;
        let%Async token = Sihl.App.Http.requireAuthorizationToken(req);
        let%Async user = Service.User.authenticate(conn, token);
        let%Async _ = Service.User.logout((conn, user));
        let response = user |> Model.User.t_encode;
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
    Sihl.App.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/register/|j},
      handler: (conn, req) => {
        open! Sihl.App.Http.Endpoint;
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
  type body_out = {message: string};

  let endpoint = (root, database) =>
    Sihl.App.Http.dbEndpoint({
      database,
      verb: GET,
      path: {j|/$root/confirm-email/|j},
      handler: (conn, req) => {
        open! Sihl.App.Http.Endpoint;
        let%Async {token} = req.requireQuery(query_decode);
        let%Async _ = Service.User.confirmEmail(conn, ~token);
        let response = {message: "Email confirmed"} |> body_out_encode;
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
    Sihl.App.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/request-password-reset/|j},
      handler: (conn, req) => {
        open! Sihl.App.Http.Endpoint;
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
    Sihl.App.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/reset-password/|j},
      handler: (conn, req) => {
        open! Sihl.App.Http.Endpoint;
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
    Sihl.App.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/update-password/|j},
      handler: (conn, req) => {
        open! Sihl.App.Http.Endpoint;
        let%Async token = Sihl.App.Http.requireAuthorizationToken(req);
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
    Sihl.App.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/set-password/|j},
      handler: (conn, req) => {
        open! Sihl.App.Http.Endpoint;
        let%Async token = Sihl.App.Http.requireAuthorizationToken(req);
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
    Sihl.App.Http.dbEndpoint({
      database,
      verb: POST,
      path: {j|/$root/update-user-details/|j},
      handler: (conn, req) => {
        open! Sihl.App.Http.Endpoint;
        let%Async token = Sihl.App.Http.requireAuthorizationToken(req);
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
      Sihl.App.Http.dbEndpoint({
        database,
        verb: GET,
        path: {j|/admin/|j},
        handler: (conn, req) => {
          open! Sihl.App.Http.Endpoint;
          let%Async {session} = req.requireQuery(query_decode);
          switch (session) {
          | None =>
            let%Async token =
              Sihl.App.Http.requireSessionCookie(req, "/admin/login/");
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
      Sihl.App.Http.dbEndpoint({
        database,
        verb: GET,
        path: {j|/admin/login/|j},
        handler: (conn, req) => {
          open! Sihl.App.Http.Endpoint;
          let%Async token = Sihl.App.Http.sessionCookie(req);
          let%Async {email, password} = req.requireQuery(query_decode);
          switch (token, email, password) {
          | (_, Some(email), Some(password)) =>
            let%Async (user, token) =
              Service.User.login(conn, ~email, ~password);
            if (!Model.User.isAdmin(user)) {
              abort @@ Unauthorized("User is not an admin");
            };
            Async.async @@ FoundRedirect("/admin?session=" ++ token.token);
          | (Some(token), _, _) =>
            let%Async isTokenValid = Service.User.isTokenValid(conn, token);
            Async.async(
              isTokenValid
                ? OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.Login />))
                : FoundRedirect("/admin?session=" ++ token),
            );
          | _ =>
            Async.async @@
            OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.Login />))
          };
        },
      });
  };

  module Logout = {
    let endpoint = (_, database) =>
      Sihl.App.Http.dbEndpoint({
        database,
        verb: POST,
        path: {j|/admin/logout/|j},
        handler: (conn, req) => {
          open! Sihl.App.Http.Endpoint;
          let%Async token =
            Sihl.App.Http.requireSessionCookie(req, "/admin/login/");
          let%Async currentUser = Service.User.authenticate(conn, token);
          let%Async _ = Service.User.logout((conn, currentUser));
          Async.async @@ FoundRedirect("/admin/login");
        },
      });
  };

  module User = {
    [@decco]
    type query = {
      action: option(string),
      password: option(string),
    };

    [@decco]
    type params = {userId: string};

    let endpoint = (root, database) =>
      Sihl.App.Http.dbEndpoint({
        database,
        verb: GET,
        path: {j|/admin/$root/users/:userId/|j},
        handler: (conn, req) => {
          open! Sihl.App.Http.Endpoint;
          let%Async token =
            Sihl.App.Http.requireSessionCookie(req, "/admin/login/");
          let%Async currentUser = Service.User.authenticate(conn, token);
          let%Async {userId} = req.requireParams(params_decode);
          let%Async user =
            Service.User.get((conn, currentUser), ~userId)
            |> abortIfErr(NotFound("User not found"));
          let%Async {action, password} = req.requireQuery(query_decode);
          switch (action, password) {
          | (None, _) =>
            Async.async @@
            OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.User user />))
          | (Some("set-password"), Some(password)) =>
            let%Async _ =
              Service.User.setPassword(
                (conn, currentUser),
                ~userId,
                ~newPassword=password,
              );
            Async.async @@
            OkHtml(
              AdminUi.HtmlTemplate.render(
                <AdminUi.User user msg="Successfully set password!" />,
              ),
            );
          | (Some(action), _) =>
            Sihl.Common.Log.error(
              "Invalid action=" ++ action ++ " provided",
              (),
            );
            Async.async @@
            OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.User user />));
          };
        },
      });
  };

  module Users = {
    let endpoint = (root, database) =>
      Sihl.App.Http.dbEndpoint({
        database,
        verb: GET,
        path: {j|/admin/$root/users/|j},
        handler: (conn, req) => {
          open! Sihl.App.Http.Endpoint;
          let%Async token =
            Sihl.App.Http.requireSessionCookie(req, "/admin/login/");
          let%Async user = Service.User.authenticate(conn, token);
          let%Async users = Service.User.getAll((conn, user));
          let users = users |> Sihl.Common.Db.Result.Query.rows;
          Async.async @@
          OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.Users users />));
        },
      });
  };
};
