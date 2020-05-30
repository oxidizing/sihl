open Base

let ( let* ) = Lwt.bind

module Dashboard = struct
  open Sihl.Http

  let handler =
    get "/admin/dashboard/" @@ fun req ->
    let email = Sihl.Authn.authenticate req |> Sihl.User.email in
    let flash = Sihl.Middleware.Flash.current req in
    let ctx = Sihl.Template.context ~flash () in
    Sihl.Admin.render ctx Sihl.Admin.Component.DashboardPage.createElement email
    |> Res.html |> Lwt.return
end
