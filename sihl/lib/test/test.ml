module Config = Sihl__config.Config
module Model = Sihl__model.Model

let with_db (f : Caqti_lwt.connection -> 'a Lwt.t) : 'a =
  let database_uri = Config.database_url () in
  match
    Lwt_main.run
      (Caqti_lwt.with_connection database_uri (fun conn ->
           f conn |> Lwt.map Result.ok))
    |> Result.map_error Caqti_error.show
  with
  (* TODO replace all failwith with raise *)
  | Error msg -> failwith msg
  | Ok v -> v
;;

let tables () : string list =
  Model.models
  |> Hashtbl.to_seq_values
  |> Seq.map (fun (model : Model.generic) -> model.name)
  |> List.of_seq
  |> List.cons "schema_migrations"
;;

let db_flush () : unit Lwt.t =
  let truncate_stmt =
    tables ()
    |> List.map (Format.sprintf "\"%s\"")
    |> String.concat ", "
    |> Format.sprintf "TRUNCATE %s RESTART IDENTITY"
  in
  let truncate =
    Caqti_request.Infix.(Caqti_type.(unit ->. unit)) @@ truncate_stmt
  in
  let database_uri = Config.database_url () in
  Caqti_lwt.with_connection
    database_uri
    (fun (module Db : Caqti_lwt.CONNECTION) ->
      Db.with_transaction (fun () -> Db.exec truncate ()))
  |> Lwt_result.map_error Caqti_error.show
  |> Lwt.map CCResult.get_or_failwith
;;

let tables_drop () : unit Lwt.t =
  (* "DROP TABLE a_models, customers CASCADE;" *)
  let drop_stmt =
    tables ()
    |> String.concat ", "
    |> Format.sprintf "DROP TABLE IF EXISTS %s CASCADE"
  in
  let drop = Caqti_request.Infix.(Caqti_type.(unit ->. unit)) @@ drop_stmt in
  let database_uri = Config.database_url () in
  Caqti_lwt.with_connection
    database_uri
    (fun (module Db : Caqti_lwt.CONNECTION) ->
      Db.with_transaction (fun () -> Db.exec drop ()))
  |> Lwt_result.map_error Caqti_error.show
  |> Lwt.map CCResult.get_or_failwith
;;

module Assert = struct
  let sexp_of_string = Sexplib0.Sexp_conv.sexp_of_string
  let sexp_of_int = Sexplib0.Sexp_conv.sexp_of_int
  let compare_string = String.compare
  let compare_int = Int.compare
  let compare_bool = Bool.compare
end
