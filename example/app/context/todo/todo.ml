(* The service provides functionality to the outside world and is the main
   entry point to the "todo" context.

   Once a request makes it to the service, we can safely assume that the
   request has been validated and authorized. Business rules that can
   not be placed in the model go here. The service calls models and
   repositories.
*)

module Model = Model

let cleaner = Repo.clean

let to_yojson todo =
  let open Model in
  `Assoc
    [ "id", `String todo.id
    ; "description", `String todo.description
    ; ( "status"
      , `String
          (match todo.status with
          | Active -> "active"
          | Done -> "done") )
    ; "created_at", `String (Ptime.to_rfc3339 todo.created_at)
    ; "updated_at", `String (Ptime.to_rfc3339 todo.updated_at)
    ]
;;

let create description =
  let open Lwt.Syntax in
  let open Model in
  let todo = Model.create description in
  let* () = Repo.insert todo in
  Repo.find todo.id
;;

let find id = Repo.find id
let find_opt id = Repo.find_opt id

let is_done todo =
  let open Model in
  match todo.status with
  | Active -> false
  | Done -> true
;;

let do_ todo =
  let updated = Model.{ todo with status = Done } in
  Repo.update updated
;;

let search ?(sort = `Desc) ?filter limit = Repo.search sort filter limit
