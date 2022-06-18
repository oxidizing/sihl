let log_src = Logs.Src.create "sihl.config"

module Logs = (val Logs.src_log log_src : Logs.LOG)

module type CONFIG = sig
  val database_url : string
  val sihl_secret : string
  val login_url : string
end

let config = ref None

let get_config () =
  match !config with
  | Some config -> config
  | None -> failwith "config has not been initialized"
;;

let database_url () =
  let module Config = (val get_config () : CONFIG) in
  Uri.of_string Config.database_url
;;

type database =
  | Postgresql
  | Mariadb

let database () : database =
  match Uri.scheme @@ database_url () with
  | Some "postgresql" | Some "postgres" -> Postgresql
  | Some "mariadb" -> Mariadb
  | Some "mysql" ->
    Logs.warn (fun m ->
        m "database MySQL not supported, falling back to MariaDB");
    Mariadb
  | Some other ->
    failwith
    @@ Format.sprintf
         "database host '%s' not supported, use postgresql://, mariadb:// or \
          sqlite:// instead"
         other
  | None -> failwith "no database configured"
;;

let configure (module Config : CONFIG) = config := Some (module Config)

let absolute_path (project_path : string) =
  (* TODO implement *)
  project_path
;;

let login_url () : string =
  let module Config = (val get_config () : CONFIG) in
  Config.login_url
;;

module Default = Config_default

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

let store data =
  List.iter
    (fun (key, value) ->
      if String.equal "" value then () else Unix.putenv key value)
    data
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
    let markers = [ ".root"; ".git"; ".hg"; ".svn"; ".bzr"; "_darcs" ] in
    let rec find_markers path_els =
      let path = String.concat "/" path_els in
      if List.exists
           (fun marker -> Sys.file_exists (path ^ "/" ^ marker))
           markers
      then (
        (* Path found => Write it into the env var to "memoize" it *)
        Unix.putenv "ROOT_PATH" path;
        Some path)
      else (
        match path_els with
        | [] -> None
        | _ -> find_markers @@ CCList.take (List.length path_els - 1) path_els)
    in
    find_markers @@ String.split_on_char '/' (Unix.getcwd ())
  | Some path -> Some path
;;

let env_files_path () =
  match Sys.getenv_opt "ENV_FILES_PATH" with
  | None | Some "" -> root_path ()
  | Some path -> Some path
;;

let read_env_file () =
  match env_files_path () with
  | Some path ->
    let filename = path ^ "/" ^ ".env" in
    let exists = CCIO.File.exists filename in
    if exists
    then (
      Logs.info (fun m -> m "env file found at %s" filename);
      let envs = CCIO.read_lines_l (open_in filename) in
      Some (envs_to_kv envs))
    else None
  | None ->
    Logs.debug (fun m ->
        m
          "no env files directory found, please provide your own directory \
           path with environment variable ENV_FILES_PATH if you would like to \
           use env files");
    None
;;

let load_env_file () =
  let file_configuration = read_env_file () in
  store (Option.value file_configuration ~default:[])
;;

let environment_variables () =
  load_env_file ();
  Unix.environment () |> Array.to_list |> envs_to_kv
;;
