type database =
  | Postgresql
  | Mariadb

let bool ?default k =
  match Sys.getenv_opt k, default with
  | Some "true", _ | Some "True", _ | Some "1", _ -> true
  | Some "false", _ | Some "False", _ | Some "0", _ -> false
  | None, Some d -> d
  | _ -> failwith @@ Format.sprintf "environment var %s was not set" k
;;

let string ?default k =
  match Sys.getenv_opt k, default with
  | Some v, _ -> v
  | None, Some d -> d
  | None, None -> failwith @@ Format.sprintf "environment var %s was not set" k
;;

let int ?default k =
  match Option.bind (Sys.getenv_opt k) int_of_string_opt, default with
  | Some v, _ -> v
  | None, Some d -> d
  | None, None ->
    failwith
    @@ Format.sprintf "environment var %s was not set or it is not an integer" k
;;

let envs_to_kv envs =
  envs
  |> List.map (String.split_on_char '=')
  |> List.map (function
         | [] -> "", ""
         | [ key ] -> key, ""
         | [ key; value ] -> key, value
         | key :: values -> key, String.concat "" values)
;;

(* .env file handling *)
let root_path () =
  match Sys.getenv_opt "ROOT_PATH" with
  | None | Some "" ->
    let markers =
      [ "dune-project"
      ; ".root"
      ; ".git"
      ; ".gitignore"
      ; ".hg"
      ; ".svn"
      ; ".bzr"
      ; "_darcs"
      ]
    in
    let rec find_markers path_els =
      let path = String.concat "/" path_els in
      if List.exists
           (fun marker -> Sys.file_exists (path ^ "/" ^ marker))
           markers
      then (
        (* Path found => Write it into the env var to "memoize" it *)
        Unix.putenv "ROOT_PATH" path;
        path)
      else (
        match path_els with
        | [] ->
          failwith
            "could not determine root project path, please create a marker \
             such as .git or dune-project or set ROOT_PATH"
        | _ -> find_markers @@ CCList.take (List.length path_els - 1) path_els)
    in
    find_markers @@ String.split_on_char '/' (Unix.getcwd ())
  | Some path -> path
;;

let absolute_path (relative_path : string) =
  Filename.concat (root_path ()) relative_path
;;

let env_files_dir () = string ~default:(root_path ()) "ENV_FILES_PATH"

let read_env_file path =
  let envs = CCIO.read_lines_l (open_in path) in
  envs_to_kv envs
;;

let configure data =
  List.iter
    (fun (key, value) ->
      if String.equal "" value then () else Unix.putenv key value)
    data
;;

let load_env_file_if_exists filename =
  let path = Filename.concat (env_files_dir ()) filename in
  if CCIO.File.exists path
  then (
    let file_configuration = read_env_file path in
    configure file_configuration)
;;

let port () = int "PORT"
let host () = string "HOST"
let debug () = bool "SIHL_DEBUG"
let database_url () = Uri.of_string @@ string "DATABASE_URL"
let login_path () = string "LOGIN_PATH"
let bin_dune () = absolute_path "_opam/bin/dune"
let bin_app_path () = absolute_path "_build/default/bin/bin.exe"
let static_url () = string ~default:"/static" "STATIC_URL"

let static_dir () =
  Filename.concat (root_path ()) @@ string ~default:"static" "STATIC_DIR"
;;

let database () : database =
  match Uri.scheme @@ database_url () with
  | Some "postgresql" | Some "postgres" -> Postgresql
  | Some "mariadb" -> Mariadb
  | Some "mysql" ->
    print_endline "database MySQL not supported, falling back to MariaDB";
    Mariadb
  | Some other ->
    failwith
    @@ Format.sprintf
         "database host %s not supported, use postgresql:// or mariadb://"
         other
  | None -> failwith "no database configured"
;;

let () =
  load_env_file_if_exists ".env.base";
  match string ~default:"local" "SIHL_ENV" with
  | "local" -> load_env_file_if_exists ".env.local"
  | "test" -> load_env_file_if_exists ".env.test"
  | "production" -> load_env_file_if_exists ".env.production"
  | _ -> load_env_file_if_exists ".env.local"
;;
