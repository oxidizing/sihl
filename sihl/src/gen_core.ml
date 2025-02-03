type gen_type =
  | Float
  | Int
  | Bool
  | String
  | Datetime

let gen_type_to_example = function
  | Float -> "0.3"
  | Int -> "10"
  | Bool -> "true"
  | String -> {|"foobar"|}
  | Datetime -> "(Ptime.of_float_s 1.0 |> Option.get)"
;;

let ocaml_type_of_gen_type = function
  | Float -> "float"
  | Int -> "int"
  | Bool -> "bool"
  | String -> "string"
  | Datetime -> "Ptime.t"
;;

let caqti_type_of_gen_type = function
  | Float -> "float"
  | Int -> "int"
  | Bool -> "bool"
  | String -> "string"
  | Datetime -> "ptime"
;;

let conformist_type_of_gen_type = function
  | Float -> "float"
  | Int -> "int"
  | Bool -> "bool"
  | String -> "string"
  | Datetime -> "datetime"
;;

let gen_type_of_string (s : string) : (gen_type, string) result =
  match s with
  | "float" -> Ok Float
  | "int" -> Ok Int
  | "bool" -> Ok Bool
  | "string" -> Ok String
  | "datetime" -> Ok Datetime
  | s -> Error (Format.sprintf "Invalid type '%s' provided" s)
;;

type schema = (string * gen_type) list

let schema_of_string (s : string list) : (schema, string) result =
  s
  |> List.map (String.split_on_char ':')
  |> List.map (fun s ->
    match s with
    | [ name; type_ ] -> Ok (name, type_)
    | _ ->
      Error (Format.sprintf "Invalid input provided '%s'" (String.concat ":" s)))
  |> List.fold_left
       (fun schema next ->
          match schema, next with
          | Ok schema, Ok (name, type_) ->
            (match gen_type_of_string type_ with
             | Ok gen_type -> Ok (List.cons (name, gen_type) schema)
             | Error msg -> Error msg)
          | Error msg, _ -> Error msg
          | Ok _, Error msg -> Error msg)
       (Result.ok [])
  |> Result.map List.rev
;;

type file =
  { name : string
  ; template : string
  ; params : (string * string) list
  }

let render { template; params; _ } =
  List.fold_left
    (fun res (name, value) ->
       CCString.replace
         ~which:`All
         ~sub:(Format.sprintf "{{%s}}" name)
         ~by:value
         res)
    template
    params
;;

let write_file (file : file) (path : string) : unit =
  let content = render file in
  let filepath = Format.sprintf "%s/%s" path file.name in
  try
    Bos.OS.File.write (Fpath.of_string filepath |> Result.get_ok) content
    |> Result.get_ok;
    print_endline (Format.sprintf "Wrote file '%s'" filepath)
  with
  | _ ->
    let msg = Format.sprintf "Failed to write file '%s'" filepath in
    print_endline msg;
    failwith msg
;;

let write_files_and_create_dir path files =
  Bos.OS.Dir.create (Fpath.of_string path |> Result.get_ok) |> ignore;
  List.iter (fun file -> write_file file path) files
;;

let write_in_domain (context : string) (files : file list) : unit =
  let root = Core_configuration.root_path () |> Option.get in
  let model_path = Format.sprintf "%s/app/domain/%s" root context in
  match Bos.OS.Dir.exists (Fpath.of_string model_path |> Result.get_ok) with
  | Ok true -> failwith (Format.sprintf "Model '%s' exists already" model_path)
  | Ok false | Error _ -> write_files_and_create_dir model_path files
;;

let write_in_test (name : string) (files : file list) : unit =
  let root = Core_configuration.root_path () |> Option.get in
  let test_path = Format.sprintf "%s/test/%s" root name in
  match Bos.OS.Dir.exists (Fpath.of_string test_path |> Result.get_ok) with
  | Ok true -> failwith (Format.sprintf "Test '%s' exists already" test_path)
  | Ok false | Error _ -> write_files_and_create_dir test_path files
;;

let write_in_database (file : file) : unit =
  let root = Core_configuration.root_path () |> Option.get in
  let path = Format.sprintf "%s/database" root in
  Bos.OS.Dir.create (Fpath.of_string path |> Result.get_ok) |> ignore;
  List.iter (fun file -> write_file file path) [ file ]
;;

let write_in_view (name : string) (files : file list) : unit =
  let root = Core_configuration.root_path () |> Option.get in
  let view_path = Format.sprintf "%s/web/view/%s" root name in
  match Bos.OS.Dir.exists (Fpath.of_string view_path |> Result.get_ok) with
  | Ok true -> failwith (Format.sprintf "View '%s' exists already" view_path)
  | Ok false | Error _ -> write_files_and_create_dir view_path files
;;

type database =
  | MariaDb
  | PostgreSql

let database_of_string = function
  | "mariadb" -> MariaDb
  | "postgresql" -> PostgreSql
  | database ->
    failwith
      (Format.sprintf
         "Invalid database provided '%s', only 'mariadb' and 'postgresql' \
          supported"
         database)
;;
