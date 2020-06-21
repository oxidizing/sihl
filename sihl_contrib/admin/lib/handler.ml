open Base

let ( let* ) = Lwt.bind

module Dashboard = struct
  open Sihl.Http

  let handler =
    get "/admin/dashboard/" @@ fun req ->
    let email = Sihl.Authn.authenticate req |> Sihl.User.email in
    let* flash =
      Sihl.Middleware.Flash.current req
      |> Lwt_result.map_err Sihl.Core.Err.raise_server
      |> Lwt.map Result.ok_exn
    in
    let ctx = Sihl.Template.context ~flash () in
    Sihl.Admin.render ctx Sihl.Admin.Component.DashboardPage.createElement email
    |> Res.html |> Lwt.return
end

module Catch = struct
  open Sihl.Http

  let handler =
    all "/admin/**" @@ fun req ->
    let path = req |> Opium.Std.Request.uri |> Uri.to_string in
    Sihl.Middleware.Flash.redirect_with_error req ~path:"/admin/dashboard/"
      (Printf.sprintf "Path %s not found :(" path)
    |> Lwt_result.map_err Sihl.Core.Err.raise_server
    |> Lwt.map Result.ok_exn
end
