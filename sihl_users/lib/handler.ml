open Base

let ( let* ) = Lwt.bind

module Login = struct
  open Sihl_core

  type body_out = { token : string } [@@deriving yojson]

  let handler =
    Http.get "/users/login/" @@ fun req ->
    let user = Service.User.authenticate req in
    let* token = Service.User.token req user in
    let response = { token = Model.Token.value token } in
    response |> body_out_to_yojson |> Yojson.Safe.to_string
    |> Http.Response.json |> Lwt.return
end

module Register = struct
  open Sihl_core

  type body_in = { email : string; username : string option; password : string }
  [@@deriving yojson]

  let handler =
    Http.post "/users/register/" @@ fun req ->
    let* { email; username; password } =
      Sihl_core.Http.require_body_exn req body_in_of_yojson
    in
    let* _ = Service.User.register req ~email ~username ~password in
    Http.Response.empty |> Lwt.return
end

module GetMe = struct
  open Sihl_core

  type body_out = Model.User.t [@@deriving yojson]

  let handler =
    Http.get "/users/users/me/" @@ fun req ->
    let response = Service.User.authenticate req in
    response |> body_out_to_yojson |> Yojson.Safe.to_string
    |> Http.Response.json |> Lwt.return
end

module Logout = struct
  open Sihl_core

  let handler =
    Http.delete "/users/logout/" @@ fun req ->
    let user = Service.User.authenticate req in
    let* () = Service.User.logout req user in
    Http.Response.empty |> Lwt.return
end

module GetUser = struct
  open Sihl_core

  type body_out = Model.User.t [@@deriving yojson]

  let handler =
    Http.get "/users/users/:id/" @@ fun req ->
    let user_id = Http.param req "id" in
    let user = Service.User.authenticate req in
    let* response = Service.User.get req user ~user_id in
    response |> body_out_to_yojson |> Yojson.Safe.to_string
    |> Http.Response.json |> Lwt.return
end

module GetUsers = struct
  open Sihl_core

  type body_out = Model.User.t list [@@deriving yojson]

  let handler =
    Http.get "/users/users/" @@ fun req ->
    let user = Service.User.authenticate req in
    let* response = Service.User.get_all req user in
    response |> body_out_to_yojson |> Yojson.Safe.to_string
    |> Http.Response.json |> Lwt.return
end

module UpdatePassword = struct
  open Sihl_core

  type body_in = {
    email : string;
    old_password : string;
    new_password : string;
  }
  [@@deriving yojson]

  let handler =
    Http.post "/users/update-password/" @@ fun req ->
    let* { email; old_password; new_password } =
      Http.require_body_exn req body_in_of_yojson
    in
    let user = Service.User.authenticate req in
    let* _ =
      Service.User.update_password req user ~email ~old_password ~new_password
    in
    Http.Response.empty |> Lwt.return
end

module UpdateDetails = struct
  open Sihl_core

  type body_in = { email : string; username : string option }
  [@@deriving yojson]

  type body_out = Model.User.t [@@deriving yojson]

  let handler =
    Http.post "/users/update-details/" @@ fun req ->
    let* { email; username } =
      Sihl_core.Http.require_body_exn req body_in_of_yojson
    in
    let user = Service.User.authenticate req in
    let* user = Service.User.update_details req user ~email ~username in
    user |> body_out_to_yojson |> Yojson.Safe.to_string |> Http.Response.json
    |> Lwt.return
end

module SetPassword = struct
  open Sihl_core

  type body_in = { user_id : string; password : string } [@@deriving yojson]

  let handler =
    Http.post "/users/set-password/" @@ fun req ->
    let* { user_id; password } = Http.require_body_exn req body_in_of_yojson in
    let user = Service.User.authenticate req in
    let* _ = Service.User.set_password req user ~user_id ~password in
    Http.Response.empty |> Lwt.return
end

module ConfirmEmail = struct
  open Sihl_core

  let handler =
    Http.get "/users/confirm-email/" @@ fun req ->
    let token = Http.query req "token" in
    let* () = Service.User.confirm_email req token in
    Http.Response.empty |> Lwt.return
end

module RequestPasswordReset = struct
  open Sihl_core

  type body_in = { email : string } [@@deriving yojson]

  let handler =
    Http.post "/users/request-password-reset/" @@ fun req ->
    let* { email } = Http.require_body_exn req body_in_of_yojson in
    let* () = Service.User.request_password_reset req ~email in
    Http.Response.empty |> Lwt.return
end

module ResetPassword = struct
  open Sihl_core

  type body_in = { token : string; new_password : string } [@@deriving yojson]

  let handler =
    Http.post "/users/reset-password/" @@ fun req ->
    let* { token; new_password } =
      Http.require_body_exn req body_in_of_yojson
    in
    let* () = Service.User.reset_password req ~token ~new_password in
    Http.Response.empty |> Lwt.return
end

module AdminUi = struct
  module Dashboard = struct
    open Tyxml.Html
    open Sihl_core

    let mycontent =
      div
        ~a:[ a_class [ "content" ] ]
        [ h1 [ txt "A fabulous title" ]; txt "This is a fabulous content." ]

    let mytitle = title (txt "A Fabulous Web Page")

    let page = html (head mytitle []) (body [ mycontent ])

    let handler =
      Sihl_core.Http.get "/users/admin/" @@ fun _ ->
      Caml.Format.asprintf "%a" (pp ()) page |> Http.Response.html |> Lwt.return
  end
end

(* module AdminUi = {
 *   module Dashboard = {
 *     [@decco]
 *     type query = {session: option(string)};
 *
 *     let endpoint = (_, database) =>
 *       Sihl.App.Http.dbEndpoint({
 *         database,
 *         verb: GET,
 *         path: {j|/admin/|j},
 *         handler: (conn, req) => {
 *           open! Sihl.App.Http.Endpoint;
 *           let%Async {session} = req.requireQuery(query_decode);
 *           switch (session) {
 *           | None =>
 *             let%Async token =
 *               Sihl.App.Http.requireSessionCookie(req, "/admin/login/");
 *             let%Async user = Service.User.authenticate(conn, token);
 *             if (!Model.User.isAdmin(user)) {
 *               abort @@ Unauthorized("User is not an admin");
 *             };
 *             Async.async @@
 *             OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.Dashboard user />));
 *           | Some(token) =>
 *             let%Async user = Service.User.authenticate(conn, token);
 *             if (!Model.User.isAdmin(user)) {
 *               abort @@ Unauthorized("User is not an admin");
 *             };
 *             let headers =
 *               [Model.Token.setCookieHeader(token)] |> Js.Dict.fromList;
 *             Async.async @@
 *             OkHtmlWithHeaders(
 *               AdminUi.HtmlTemplate.render(<AdminUi.Dashboard user />),
 *               headers,
 *             );
 *           };
 *         },
 *       });
 *   };
 *
 *   module Login = {
 *     [@decco]
 *     type query = {
 *       email: option(string),
 *       password: option(string),
 *     };
 *
 *     let endpoint = (_, database) =>
 *       Sihl.App.Http.dbEndpoint({
 *         database,
 *         verb: GET,
 *         path: {j|/admin/login/|j},
 *         handler: (conn, req) => {
 *           open! Sihl.App.Http.Endpoint;
 *           let%Async token = Sihl.App.Http.sessionCookie(req);
 *           let%Async {email, password} = req.requireQuery(query_decode);
 *           switch (token, email, password) {
 *           | (_, Some(email), Some(password)) =>
 *             let%Async (user, token) =
 *               Service.User.login(conn, ~email, ~password);
 *             if (!Model.User.isAdmin(user)) {
 *               abort @@ Unauthorized("User is not an admin");
 *             };
 *             Async.async @@ FoundRedirect("/admin?session=" ++ token.token);
 *           | (Some(token), _, _) =>
 *             let%Async isTokenValid = Service.User.isTokenValid(conn, token);
 *             Async.async(
 *               isTokenValid
 *                 ? OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.Login />))
 *                 : FoundRedirect("/admin?session=" ++ token),
 *             );
 *           | _ =>
 *             Async.async @@
 *             OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.Login />))
 *           };
 *         },
 *       });
 *   };
 *
 *   module Logout = {
 *     let endpoint = (_, database) =>
 *       Sihl.App.Http.dbEndpoint({
 *         database,
 *         verb: POST,
 *         path: {j|/admin/logout/|j},
 *         handler: (conn, req) => {
 *           open! Sihl.App.Http.Endpoint;
 *           let%Async token =
 *             Sihl.App.Http.requireSessionCookie(req, "/admin/login/");
 *           let%Async currentUser = Service.User.authenticate(conn, token);
 *           let%Async _ = Service.User.logout((conn, currentUser));
 *           Async.async @@ FoundRedirect("/admin/login");
 *         },
 *       });
 *   };
 *
 *   module User = {
 *     [@decco]
 *     type query = {
 *       action: option(string),
 *       password: option(string),
 *     };
 *
 *     [@decco]
 *     type params = {userId: string};
 *
 *     let endpoint = (root, database) =>
 *       Sihl.App.Http.dbEndpoint({
 *         database,
 *         verb: GET,
 *         path: {j|/admin/$root/users/:userId/|j},
 *         handler: (conn, req) => {
 *           open! Sihl.App.Http.Endpoint;
 *           let%Async token =
 *             Sihl.App.Http.requireSessionCookie(req, "/admin/login/");
 *           let%Async currentUser = Service.User.authenticate(conn, token);
 *           let%Async {userId} = req.requireParams(params_decode);
 *           let%Async user =
 *             Service.User.get((conn, currentUser), ~userId)
 *             |> abortIfErr(NotFound("User not found"));
 *           let%Async {action, password} = req.requireQuery(query_decode);
 *           switch (action, password) {
 *           | (None, _) =>
 *             Async.async @@
 *             OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.User user />))
 *           | (Some("set-password"), Some(password)) =>
 *             let%Async _ =
 *               Service.User.setPassword(
 *                 (conn, currentUser),
 *                 ~userId,
 *                 ~newPassword=password,
 *               );
 *             Async.async @@
 *             OkHtml(
 *               AdminUi.HtmlTemplate.render(
 *                 <AdminUi.User user msg="Successfully set password!" />,
 *               ),
 *             );
 *           | (Some(action), _) =>
 *             Sihl.Core.Log.error(
 *               "Invalid action=" ++ action ++ " provided",
 *               (),
 *             );
 *             Async.async @@
 *             OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.User user />));
 *           };
 *         },
 *       });
 *   };
 *
 *   module Users = {
 *     let endpoint = (root, database) =>
 *       Sihl.App.Http.dbEndpoint({
 *         database,
 *         verb: GET,
 *         path: {j|/admin/$root/users/|j},
 *         handler: (conn, req) => {
 *           open! Sihl.App.Http.Endpoint;
 *           let%Async token =
 *             Sihl.App.Http.requireSessionCookie(req, "/admin/login/");
 *           let%Async user = Service.User.authenticate(conn, token);
 *           let%Async users = Service.User.getAll((conn, user));
 *           let users = users |> Sihl.Core.Db.Result.Query.rows;
 *           Async.async @@
 *           OkHtml(AdminUi.HtmlTemplate.render(<AdminUi.Users users />));
 *         },
 *       });
 *   }; *)
