let env_string _ = "todo"
let env_bool _ = true
let log_src = Logs.Src.create "sihl.config"

module Logs = (val Logs.src_log log_src : Logs.LOG)

module type CONFIG = sig
  val database_url : string
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
  | Sqlite

let database () : database =
  match Uri.scheme @@ database_url () with
  | Some "postgresql" | Some "postgres" -> Postgresql
  | Some "mariadb" -> Mariadb
  | Some "mysql" ->
    Logs.warn (fun m ->
        m "database MySQL not supported, falling back to MariaDB");
    Mariadb
  | Some "sqlite" -> Sqlite
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
