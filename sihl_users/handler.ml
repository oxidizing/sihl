open Core
open Opium.Std

let login =
  get "/users/login/" (fun req ->
      let open Lwt in
      let user = Service.User.authenticate req in
      Service.User.token req user >>= fun token ->
      match token with
      | Ok token ->
          `String (Printf.sprintf "token=%s" (Model.Token.value token))
          |> respond'
      | Error msg -> `String (Printf.sprintf "error=%s" msg) |> respond')

let register =
  get "/users/register/" (fun _ -> `String "not implemented" |> respond')

let logout =
  get "/users/logout/" (fun _ -> `String "not implemented" |> respond')

let get_user =
  get "/users/users/:id/" (fun _ -> `String "not implemented" |> respond')

let get_users =
  get "/users/users/" (fun _ -> `String "this is a list of users" |> respond')

let get_me =
  get "/users/users/me/" (fun _ -> `String "not implemented" |> respond')

let routes = [ login; register; logout; get_user; get_users; get_me ]

let add_handlers app =
  Core.List.fold ~f:(fun app route -> route app) ~init:app routes
