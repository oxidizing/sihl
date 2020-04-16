open Core
open Opium.Std

let ( let* ) = Lwt.bind

module Login = struct
  let handler =
    get "/users/login/" (fun req ->
        let user = Service.User.authenticate req in
        let* token = Service.User.token req user in
        match token with
        | Ok token ->
            `String (Printf.sprintf "token=%s" (Model.Token.value token))
            |> respond'
        | Error msg -> `String (Printf.sprintf "error=%s" msg) |> respond')
end

module Register = struct
  type body_in = {
    email : string;
    username : string;
    password : string;
    name : string;
  }
  [@@deriving yojson]

  let handler =
    post "/users/register/" (fun req ->
        let* body = req |> Request.body |> Cohttp_lwt.Body.to_string in
        match body |> Yojson.Safe.from_string |> body_in_of_yojson with
        | Ok body_in -> (
            let* () = Logs_lwt.info (fun m -> m "Get HTTP request") in
            let* result =
              Service.User.register req ~email:body_in.email
                ~username:body_in.username ~password:body_in.password
                ~name:body_in.name
            in
            match result with
            | Ok _ -> respond' @@ `String "ok"
            | Error msg -> respond' @@ `String ("failed msg=" ^ msg) )
        | Error _ -> `String "failed to decode request" |> respond')
end

let logout =
  get "/users/logout/" (fun _ -> `String "not implemented" |> respond')

let get_user =
  get "/users/users/:id/" (fun _ -> `String "not implemented" |> respond')

let get_users =
  get "/users/users/" (fun _ -> `String "this is a list of users" |> respond')

let get_me =
  get "/users/users/me/" (fun _ -> `String "not implemented" |> respond')

let routes =
  [ Login.handler; Register.handler; logout; get_user; get_users; get_me ]

let add_handlers app =
  Core.List.fold ~f:(fun app route -> route app) ~init:app routes
