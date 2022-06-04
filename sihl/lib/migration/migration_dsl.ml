type on_delete =
  | Cascade
  | Restrict
  | SetNull
  | NoAction

type column_type =
  | Increments of { primary_key : bool }
  | Integer of { default : int option }
  | BigInteger of { default : int option }
  | Text of { default : string option }
  | String of
      { default : string option
      ; length : int option
      }
  | Timestamp of
      { default_to_now : bool
      ; update : bool
      }
  | ForeignKey of
      { on_delete : on_delete
      ; references : string
      }

type column =
  { name : string
  ; unique : bool
  ; nullable : bool
  ; type_ : column_type
  }

type table =
  { name : string
  ; columns : column list
  ; raw : string list
  }

type migration =
  { alter : table list
  ; create : table list
  ; drop : string list
  ; raw : string list
  ; fns : (unit -> unit Lwt.t) list
  }

let migration_empty = { alter = []; create = []; drop = []; raw = []; fns = [] }

let table_column database = function
  | { name; unique; type_ = Increments _; _ } ->
    (match database with
    | Model.Postgresql ->
      Printf.sprintf "%s SERIAL %s" name (if unique then "UNIQUE" else "")
    | Model.Mariadb ->
      Printf.sprintf "%s BIGINT UNSIGNED NOT NULL AUTOINCREMENT" name
    | Sqlite -> failwith "todo")
  | { name; type_ = Integer { default }; _ } ->
    default
    |> Option.map string_of_int
    |> Option.map @@ Printf.sprintf "DEFAULT %s"
    |> Option.value ~default:""
    |> Printf.sprintf "%s INTEGER %s" name
  | { name; type_ = BigInteger { default }; _ } ->
    default
    |> Option.map string_of_int
    |> Option.map @@ Printf.sprintf "DEFAULT %s"
    |> Option.value ~default:""
    |> Printf.sprintf "%s BIGINTEGER %s" name
  | { name; type_ = Text { default }; _ } ->
    default
    |> Option.map @@ Printf.sprintf "DEFAULT %s"
    |> Option.value ~default:""
    |> Printf.sprintf "%s TEXT %s" name
  | { name; type_ = String { default; length }; _ } ->
    let default =
      default
      |> Option.map @@ Printf.sprintf "DEFAULT %s"
      |> Option.value ~default:""
    in
    let length = length |> Option.value ~default:255 |> string_of_int in
    Printf.sprintf "%s TEXT(%s) %s" name length default
  | _ -> failwith "todo"
;;

let unique_column database unique name =
  match unique, database with
  | true, Model.Postgresql -> [ Printf.sprintf "UNIQUE(%s)" name ]
  | true, Model.Mariadb -> [ Printf.sprintf "UNIQUE KEY(%s)" name ]
  | true, Sqlite -> failwith "todo"
  | false, _ -> []
;;

let create_table_column database column =
  match column with
  | { name; type_ = Increments { primary_key }; _ } ->
    let stmt = [ table_column database column ] in
    if primary_key
    then List.cons (Printf.sprintf "PRIMARY KEY (%s)" name) stmt
    else stmt
  | { name; unique; type_ = Integer _; _ } ->
    [ table_column database column ] @ unique_column database unique name
  | { name; unique; type_ = BigInteger _; _ } ->
    [ table_column database column ] @ unique_column database unique name
  | { name; unique; type_ = Text _; _ } ->
    [ table_column database column ] @ unique_column database unique name
  | _ -> failwith "todo"
;;

let create_table_columns_sql columns database =
  String.concat ","
  @@ List.flatten
  @@ List.map (create_table_column database) columns
;;

let create_table_to_sql database (table : table) =
  match database with
  | Model.Postgresql ->
    [ Printf.sprintf
        "CREATE TABLE %s IF NOT EXISTS (%s)"
        table.name
        (create_table_columns_sql table.columns database)
    ]
  | Model.Mariadb -> []
  | Model.Sqlite ->
    failwith "migrations for Sqlite are not supported at the moment"
;;

let alter_table_to_sql _ = failwith "todo"
let drop_tables_to_sql _ = []

(* Public API *)

let migration_to_sql database (migration : migration) =
  String.concat ";"
  @@ List.flatten
       [ List.flatten
         @@ List.map (create_table_to_sql database) migration.create
       ; List.flatten @@ List.map (alter_table_to_sql database) migration.alter
       ; drop_tables_to_sql migration.drop
       ; migration.raw
       ]
;;

let table (name : string) = { name; columns = []; raw = [] }

let table_create table migration =
  { migration with create = List.cons table migration.create }
;;

let table_alter table migration =
  { migration with alter = List.cons table migration.create }
;;

let table_drop table_name migration =
  { migration with drop = List.cons table_name migration.drop }
;;

let raw sql migration = { migration with raw = List.cons sql migration.raw }

let string
    ?default
    ?(unique = false)
    ?(nullable = true)
    ?length
    (name : string)
    table
  =
  let column = { name; unique; nullable; type_ = String { length; default } } in
  { table with columns = List.cons column table.columns }
;;

let increments ?(primary_key = true) (name : string) (table : table) =
  let column =
    { name
    ; unique = true
    ; nullable = false
    ; type_ = Increments { primary_key }
    }
  in
  { table with columns = List.cons column table.columns }
;;

let timestamps () table =
  let created_at_column =
    { name = "created_at"
    ; unique = false
    ; nullable = false
    ; type_ = Timestamp { default_to_now = true; update = false }
    }
  in
  let updated_at_column =
    { name = "updated_at"
    ; unique = false
    ; nullable = false
    ; type_ = Timestamp { default_to_now = false; update = true }
    }
  in
  { table with
    columns =
      table.columns
      |> List.cons created_at_column
      |> List.cons updated_at_column
  }
;;

let integer ?length:_ _ = Obj.magic

let fk ?(unique = true) ?(nullable = true) ~on_delete ~references name table =
  let column =
    { name; unique; nullable; type_ = ForeignKey { on_delete; references } }
  in
  { table with columns = List.cons column table.columns }
;;

let raw_column sql (table : table) =
  { table with raw = List.cons sql table.raw }
;;

let run fn migration = { migration with fns = List.cons fn migration.fns }
