let ml_template =
  {|
include Model

exception Exception of string

let clean =
  if Sihl.Configuration.is_production ()
  then
    raise
    @@ Exception
         "Could not clean repository in production, this is most likely not what \
          you want."
  else Repo.clean
;;

let find id = Repo.find id
let query = Repo.find_all

let insert ({{name}} : t) =
  let open Lwt.Syntax in
  let* () = Repo.insert {{name}} in
  let* inserted = Repo.find {{name}}.id in
  (match inserted with
  | Some {{name}} -> Lwt.return (Ok {{name}})
  | None ->
    Logs.err (fun m ->
        m "Failed to insert {{name}} '%a'" pp {{name}});
    Lwt.return @@ Error "Failed to insert {{name}}")
;;

let create {{create_args}} : (t, string) Result.t Lwt.t =
  insert @@ create {{create_args}}
 ;;

let update id ({{name}} : t) =
  let open Lwt.Syntax in
  let {{name}} = { {{name}} with id } in
  let* () = Repo.update {{name}} in
  let* updated = find id in
  match updated with
  | Some updated -> Lwt.return (Ok updated)
  | None -> Lwt.return @@ Error "Failed to update {{name}}"
;;

let delete ({{name}} : t) =
  Repo.delete {{name}} |> Lwt.map Result.ok
;;
|}
;;

let mli_template =
  {|
type t =
  { id : string
  {{model_type}}
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }
[@@deriving show]

val schema : (unit, {{ctor_type}} -> t, t) Conformist.t

exception Exception of string

val clean : unit -> unit Lwt.t
val find : string -> t option Lwt.t
val query : unit -> t list Lwt.t
val create : {{ctor_type}} -> (t, string) result Lwt.t
val insert : t -> (t, string) result Lwt.t
val update : string -> t -> (t, string) result Lwt.t
val delete : t -> (unit, string) result Lwt.t
|}
;;

let dune_file_template database =
  let open Gen_core in
  match database with
  | PostgreSql ->
    {|(library
 (name {{name}})
 (libraries caqti-driver-postgresql sihl service)
 (preprocess
  (pps ppx_deriving.show)))
|}
  | MariaDb ->
    {|(library
 (name {{name}})
 (libraries caqti-driver-mariadb sihl service)
 (preprocess
  (pps ppx_deriving.show)))
|}
;;

let generate (database : string) (name : string) (schema : Gen_core.schema)
    : unit
  =
  let database = Gen_core.database_of_string database in
  if String.contains name ':'
  then failwith "Invalid service name provided, it can not contain ':'"
  else (
    let create_args =
      schema |> List.map (fun (name, _) -> name) |> String.concat " "
    in
    let ml_filename = Format.sprintf "%s.ml" name in
    let ml_parameters = [ "name", name; "create_args", create_args ] in
    let mli_filename = Format.sprintf "%s.mli" name in
    let mli_parameters =
      [ "model_type", Gen_model.model_type schema
      ; "ctor_type", Gen_model.ctor_type schema
      ]
    in
    let service_file =
      Gen_core.
        { name = ml_filename; template = ml_template; params = ml_parameters }
    in
    let service_interface_file =
      Gen_core.
        { name = mli_filename
        ; template = mli_template
        ; params = mli_parameters
        }
    in
    let model_file = Gen_model.file schema in
    let repo_file = Gen_repo.file database name schema in
    let dune_file =
      Gen_core.
        { name = "dune"
        ; template = dune_file_template database
        ; params = [ "name", name ]
        }
    in
    Gen_core.write_in_context
      name
      [ service_file; service_interface_file; model_file; repo_file; dune_file ];
    Gen_core.write_in_test
      name
      Gen_service_test.[ test_file name schema; dune_file name ]);
  Gen_migration.write_migration_file database name schema
;;
