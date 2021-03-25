let log_src = Logs.Src.create "sihl.core.configuration"

module Logs = (val Logs.src_log log_src : Logs.LOG)

exception Exception of string

type ('ctor, 'ty) schema = (string, 'ctor, 'ty) Conformist.t
type data = (string * string) list
type t = (string * string option * string * string option) list

let make ?schema () =
  match schema with
  | Some schema ->
    Conformist.fold_left
      ~f:(fun res field ->
        let name = Conformist.Field.name field in
        let description = Conformist.Field.meta field in
        let type_ = Conformist.Field.type_ field in
        let default = Conformist.Field.encode_default field in
        List.cons (name, description, type_, default) res)
      ~init:[]
      schema
  | None -> []
;;

let empty = []

(* We assume a total number of initial configurations of 100 *)
let cache = Hashtbl.create 100

let memoize f arg =
  try Hashtbl.find cache arg with
  | Not_found ->
    let result = f arg in
    (* We don't want to fill up the cache with None *)
    if Option.is_some result then Hashtbl.add cache arg result;
    result
;;

let store data =
  List.iter
    (fun (key, value) ->
      if String.equal "" value
      then ()
      else (
        Hashtbl.replace cache key (Some value);
        Unix.putenv key value))
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
    let markers = [ ".git"; ".hg"; ".svn"; ".bzr"; "_darcs" ] in
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
    let is_test =
      match Sys.getenv_opt "SIHL_ENV" with
      | Some "test" -> true
      | _ -> false
    in
    let filename = path ^ "/" ^ if is_test then ".env.test" else ".env" in
    let exists = CCIO.File.exists filename in
    if exists
    then (
      Logs.info (fun m -> m "Env file found: %s" filename);
      let envs = CCIO.read_lines_l (open_in filename) in
      Some (envs_to_kv envs))
    else (
      Logs.info (fun m ->
          m "Env file not found: %s. Continuing without it." filename);
      None)
  | None ->
    Logs.debug (fun m ->
        m
          "No env files directory found, please provide your own directory \
           path with environment variable ENV_FILES_PATH if you would like to \
           use env files");
    None
;;

let file_was_read = ref false

let load_env_file () =
  if !file_was_read
  then (* Nothing to do, the file was read already *) ()
  else (
    let file_configuration = read_env_file () in
    file_was_read := true;
    store (Option.value file_configuration ~default:[]))
;;

let environment_variables () =
  load_env_file ();
  Unix.environment () |> Array.to_list |> envs_to_kv
;;

let read schema =
  let data = environment_variables () in
  let data = List.map (fun (k, v) -> k, [ v ]) data in
  match Conformist.decode_and_validate schema data with
  | Ok value -> value
  | Error errors ->
    let errors =
      List.map
        (fun (field, input, msg) ->
          match input with
          | None ->
            Format.sprintf "Failed to read configuration '%s': %s" field msg
          | Some input ->
            Format.sprintf
              "Failed to read configuration '%s' for '%s': %s"
              input
              field
              msg)
        errors
    in
    List.iter (fun error -> Logs.err (fun m -> m "%s" error)) errors;
    raise (Exception "Invalid configuration provided")
;;

let read_string' key =
  load_env_file ();
  Sys.getenv_opt key
;;

let read_string = memoize read_string'

let load () =
  load_env_file ();
  match read_string "SIHL_ENV" with
  | None ->
    Logs.info (fun m ->
        m
          "SIHL_ENV not found. Set it to one of the following values: \
           development, production, test");
    raise @@ Exception "SIHL_ENV not found"
  | Some env -> Logs.info (fun m -> m "SIHL_ENV: %s" env)
;;

let is_test () =
  match read_string "SIHL_ENV" with
  | Some "test" -> true
  | _ -> false
;;

let is_development () =
  match read_string "SIHL_ENV" with
  | Some "development" -> true
  | _ -> false
;;

let is_production () =
  match read_string "SIHL_ENV" with
  | Some "production" -> true
  | _ -> false
;;

let read_secret () =
  match is_production (), read_string "SIHL_SECRET" with
  | true, Some secret ->
    (* TODO [jerben] provide proper security policy (entropy or smth) *)
    if String.length secret > 10
    then secret
    else (
      Logs.err (fun m -> m "SIHL_SECRET has to be longer than 10");
      raise @@ Exception "Insecure secret provided")
  | false, Some secret -> secret
  | true, None ->
    Logs.err (fun m -> m "Set SIHL_SECRET before deploying Sihl to production");
    raise @@ Exception "No secret provided"
  (* In testing and local dev we don't have to use real security *)
  | false, None -> "secret"
;;

let read_int key =
  match read_string key with
  | Some value -> int_of_string_opt value
  | None -> None
;;

let read_bool key =
  match read_string key with
  | Some value -> bool_of_string_opt value
  | None -> None
;;

let require schema =
  let vars = environment_variables () in
  let data = List.map (fun (k, v) -> k, [ v ]) vars in
  match Conformist.decode_and_validate schema data with
  | Ok _ -> ()
  | Error errors ->
    let errors =
      errors
      |> List.map (fun (field, input, msg) ->
             match input with
             | None ->
               Format.sprintf "Failed to read configuration '%s': %s" field msg
             | Some input ->
               Format.sprintf
                 "Failed to read configuration '%s' for '%s': %s"
                 input
                 field
                 msg)
      |> List.cons
           "There were some errors while validating the provided configuration:"
      |> String.concat "\n"
    in
    Logs.err (fun m -> m "%s" errors);
    raise (Exception "Configuration check failed")
;;

(* Displaying configurations *)

let show_configurations configurations =
  configurations
  |> List.map (fun (name, description, type_, default) ->
         Format.sprintf
           "%s, %s, %s, %s"
           name
           (Option.value ~default:"-" description)
           type_
           (Option.value ~default:"-" default))
  |> String.concat "\n"
;;

let show_cmd configurations =
  Core_command.make
    ~name:"show-config"
    ~description:"Print a list of required service configurations"
    (fun _ ->
      let header = "Name, Description, Type, Default" in
      let str =
        configurations
        |> List.filter (fun (_, configurations) ->
               List.length configurations > 0)
        |> List.map (fun (service_name, configurations) ->
               String.concat
                 "\n"
                 [ ""; service_name; show_configurations configurations ])
        |> List.cons header
        |> String.concat "\n"
      in
      Lwt.return @@ print_endline str)
;;

let commands configurations = [ show_cmd configurations ]
