(* TODO fix once we have defined user service, token service and use case layer *)

(* open Base
 *
 * let ( let* ) = Lwt.bind
 *
 * module Login = struct
 *   open Sihl.Http
 *
 *   type body_out = { token : string; user_id : string } [@@deriving yojson]
 *
 *   let handler =
 *     get "/users/login/" @@ fun req ->
 *     let (module UserService : Sihl.User.Sig.SERVICE) =
 *       Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *     in
 *     let user = Sihl.Authn.authenticate req in
 *     let* token = UserService.token req user in
 *     let response =
 *       { token = Sihl.User.Token.value token; user_id = Sihl.User.id user }
 *     in
 *     response |> body_out_to_yojson |> Yojson.Safe.to_string |> Res.json
 *     |> Lwt.return
 * end
 *
 * module Register = struct
 *   open Sihl.Http
 *
 *   type body_in = { email : string; username : string option; password : string }
 *   [@@deriving yojson]
 *
 *   let handler =
 *     post "/users/register/" @@ fun req ->
 *     let (module UserService : Sihl.User.Sig.SERVICE) =
 *       Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *     in
 *     let* { email; username; password } =
 *       Req.require_body_exn req body_in_of_yojson
 *     in
 *     let* _ = UserService.register req ~email ~username ~password in
 *     Res.empty |> Lwt.return
 * end
 *
 * module GetMe = struct
 *   open Sihl.Http
 *
 *   type body_out = Sihl.User.t [@@deriving yojson]
 *
 *   let handler =
 *     get "/users/users/me/" @@ fun req ->
 *     let user = Sihl.Authn.authenticate req in
 *     user |> body_out_to_yojson |> Yojson.Safe.to_string |> Res.json
 *     |> Lwt.return
 * end
 *
 * module Logout = struct
 *   open Sihl.Http
 *
 *   let handler =
 *     delete "/users/logout/" @@ fun req ->
 *     let (module UserService : Sihl.User.Sig.SERVICE) =
 *       Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *     in
 *     let user = Sihl.Authn.authenticate req in
 *     let* () = UserService.logout req user in
 *     Res.empty |> Lwt.return
 * end
 *
 * module GetUser = struct
 *   open Sihl.Http
 *
 *   type body_out = Sihl.User.t [@@deriving yojson]
 *
 *   let handler =
 *     get "/users/users/:id/" @@ fun req ->
 *     let (module UserService : Sihl.User.Sig.SERVICE) =
 *       Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *     in
 *     let user_id = Req.param req "id" in
 *     let user = Sihl.Authn.authenticate req in
 *     let* response = UserService.get req user ~user_id in
 *     response |> body_out_to_yojson |> Yojson.Safe.to_string |> Res.json
 *     |> Lwt.return
 * end
 *
 * module GetUsers = struct
 *   open Sihl.Http
 *
 *   type body_out = Sihl.User.t list [@@deriving yojson]
 *
 *   let handler =
 *     get "/users/users/" @@ fun req ->
 *     let user = Sihl.Authn.authenticate req in
 *     let (module UserService : Sihl.User.Sig.SERVICE) =
 *       Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *     in
 *     let* response = UserService.get_all req user in
 *     response |> body_out_to_yojson |> Yojson.Safe.to_string |> Res.json
 *     |> Lwt.return
 * end
 *
 * module UpdatePassword = struct
 *   open Sihl.Http
 *
 *   type body_in = {
 *     email : string;
 *     old_password : string;
 *     new_password : string;
 *   }
 *   [@@deriving yojson]
 *
 *   let handler =
 *     post "/users/update-password/" @@ fun req ->
 *     let (module UserService : Sihl.User.Sig.SERVICE) =
 *       Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *     in
 *     let* { email; old_password; new_password } =
 *       Req.require_body_exn req body_in_of_yojson
 *     in
 *     let user = Sihl.Authn.authenticate req in
 *     let* _ =
 *       UserService.update_password req user ~email ~old_password ~new_password
 *     in
 *     Res.empty |> Lwt.return
 * end
 *
 * module UpdateDetails = struct
 *   open Sihl.Http
 *
 *   type body_in = { email : string; username : string option }
 *   [@@deriving yojson]
 *
 *   type body_out = Sihl.User.t [@@deriving yojson]
 *
 *   let handler =
 *     post "/users/update-details/" @@ fun req ->
 *     let (module UserService : Sihl.User.Sig.SERVICE) =
 *       Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *     in
 *     let* { email; username } = Req.require_body_exn req body_in_of_yojson in
 *     let user = Sihl.Authn.authenticate req in
 *     let* user = UserService.update_details req user ~email ~username in
 *     user |> body_out_to_yojson |> Yojson.Safe.to_string |> Res.json
 *     |> Lwt.return
 * end
 *
 * module SetPassword = struct
 *   open Sihl.Http
 *
 *   type body_in = { user_id : string; password : string } [@@deriving yojson]
 *
 *   let handler =
 *     post "/users/set-password/" @@ fun req ->
 *     let (module UserService : Sihl.User.Sig.SERVICE) =
 *       Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *     in
 *     let* { user_id; password } = Req.require_body_exn req body_in_of_yojson in
 *     let user = Sihl.Authn.authenticate req in
 *     let* _ = UserService.set_password req user ~user_id ~password in
 *     Res.empty |> Lwt.return
 * end
 *
 * module ConfirmEmail = struct
 *   open Sihl.Http
 *
 *   let handler =
 *     get "/users/confirm-email/" @@ fun req ->
 *     let (module UserService : Sihl.User.Sig.SERVICE) =
 *       Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *     in
 *     let token = Req.query req "token" in
 *     let* () = UserService.confirm_email req token in
 *     Res.empty |> Lwt.return
 * end
 *
 * module RequestPasswordReset = struct
 *   open Sihl.Http
 *
 *   type body_in = { email : string } [@@deriving yojson]
 *
 *   let handler =
 *     post "/users/request-password-reset/" @@ fun req ->
 *     let (module UserService : Sihl.User.Sig.SERVICE) =
 *       Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *     in
 *     let* { email } = Req.require_body_exn req body_in_of_yojson in
 *     let* () = UserService.request_password_reset req ~email in
 *     Res.empty |> Lwt.return
 * end
 *
 * module ResetPassword = struct
 *   open Sihl.Http
 *
 *   type body_in = { token : string; new_password : string } [@@deriving yojson]
 *
 *   let handler =
 *     post "/users/reset-password/" @@ fun req ->
 *     let (module UserService : Sihl.User.Sig.SERVICE) =
 *       Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *     in
 *     let* { token; new_password } = Req.require_body_exn req body_in_of_yojson in
 *     let* () = UserService.reset_password req ~token ~new_password in
 *     Res.empty |> Lwt.return
 * end
 *
 * module AdminUi = struct
 *   module Login = struct
 *     open Sihl.Http
 *
 *     let get =
 *       get "/admin/login/" @@ fun req ->
 *       let* flash =
 *         Sihl.Middleware.Flash.current req
 *         |> Lwt_result.map_err Sihl.Core.Err.raise_server
 *         |> Lwt.map Result.ok_exn
 *       in
 *       let ctx = Sihl.Template.context ~flash () in
 *       Sihl.Admin.render ctx Sihl.Admin.Component.LoginPage.createElement ()
 *       |> Res.html |> Lwt.return
 *
 *     let post =
 *       Sihl.Http.post "/admin/login/" @@ fun req ->
 *       let (module UserService : Sihl.User.Sig.SERVICE) =
 *         Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *       in
 *       let* email, password = Req.url_encoded2 req "email" "password" in
 *       let* user =
 *         Sihl.Core.Err.try_to_run (fun () ->
 *             UserService.authenticate_credentials req ~email ~password)
 *       in
 *       match user with
 *       | Ok user ->
 *           let* () = Middleware.Authn.create_session req user in
 *           Res.empty |> Res.redirect "/admin/dashboard/" |> Lwt.return
 *       | Error _ ->
 *           Sihl.Middleware.Flash.redirect_with_error req ~path:"/admin/login/"
 *             "Provided email or password is wrong."
 *           |> Lwt_result.map_err Sihl.Core.Err.raise_server
 *           |> Lwt.map Result.ok_exn
 *   end
 *
 *   module Logout = struct
 *     open Sihl.Http
 *
 *     let handler =
 *       post "/admin/logout/" @@ fun req ->
 *       let (module UserService : Sihl.User.Sig.SERVICE) =
 *         Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *       in
 *       let user = Sihl.Authn.authenticate req in
 *       let* () = UserService.logout req user in
 *       Res.empty |> Res.stop_session
 *       |> Res.redirect "/admin/login/"
 *       |> Lwt.return
 *   end
 *
 *   module Users = struct
 *     open Sihl.Http
 *
 *     let handler =
 *       get "/admin/users/users/" @@ fun req ->
 *       let (module UserService : Sihl.User.Sig.SERVICE) =
 *         Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *       in
 *       let user = Sihl.Authn.authenticate req in
 *       let* flash =
 *         Sihl.Middleware.Flash.current req
 *         |> Lwt_result.map_err Sihl.Core.Err.raise_server
 *         |> Lwt.map Result.ok_exn
 *       in
 *
 *       let ctx = Sihl.Template.context ~flash () in
 *       let* users = UserService.get_all req user in
 *       Sihl.Admin.render ctx Admin_component_user.UserListPage.createElement
 *         users
 *       |> Res.html |> Lwt.return
 *   end
 *
 *   module User = struct
 *     open Sihl.Http
 *
 *     let handler =
 *       get "/admin/users/users/:id/" @@ fun req ->
 *       let (module UserService : Sihl.User.Sig.SERVICE) =
 *         Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *       in
 *       let user_id = Req.param req "id" in
 *       let user = Sihl.Authn.authenticate req in
 *       let* flash =
 *         Sihl.Middleware.Flash.current req
 *         |> Lwt_result.map_err Sihl.Core.Err.raise_server
 *         |> Lwt.map Result.ok_exn
 *       in
 *
 *       let ctx = Sihl.Template.context ~flash () in
 *       let* user = UserService.get req user ~user_id in
 *       Sihl.Admin.render ctx Admin_component_user.UserPage.createElement user
 *       |> Res.html |> Lwt.return
 *   end
 *
 *   module UserSetPassword = struct
 *     open Sihl.Http
 *
 *     let handler =
 *       post "/admin/users/users/:id/set-password/" @@ fun req ->
 *       let (module UserService : Sihl.User.Sig.SERVICE) =
 *         Sihl.Container.fetch_service_exn Sihl.User.Sig.key
 *       in
 *       let user_id = Req.param req "id" in
 *       let user_page = Printf.sprintf "/admin/users/users/%s/" user_id in
 *       let user = Sihl.Authn.authenticate req in
 *       let* password = Req.url_encoded req "password" in
 *       let* result =
 *         Sihl.Core.Err.try_to_run (fun () ->
 *             UserService.set_password req user ~user_id ~password)
 *       in
 *       match result with
 *       | Ok _ ->
 *           Sihl.Middleware.Flash.redirect_with_success req ~path:user_page
 *             "New password successfully set"
 *           |> Lwt_result.map_err Sihl.Core.Err.raise_server
 *           |> Lwt.map Result.ok_exn
 *       | Error error ->
 *           Logs.err (fun m -> m "%s" (Sihl.Core.Err.Error.show error));
 *           Sihl.Middleware.Flash.redirect_with_error req ~path:user_page
 *             (Sihl.Core.Err.Error.show error)
 *           |> Lwt_result.map_err Sihl.Core.Err.raise_server
 *           |> Lwt.map Result.ok_exn
 *   end
 * end *)
