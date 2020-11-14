open Lwt.Syntax

let log_src = Logs.Src.create "sihl.configuration"

module Logs = (val Logs.src_log log_src : Logs.LOG)

exception Exception of string

type data = (string * string) list
type t = data -> (string * string) list

let make ?schema () =
  match schema with
  | Some schema ->
    let validator data =
      let data = List.map (fun (k, v) -> k, [ v ]) data in
      Conformist.validate schema data
    in
    validator
  | None -> fun _ -> []
;;

let empty _ = []

let memoize f =
  (* We assume a total number of initial configurations of 100 *)
  let cache = Hashtbl.create 100 in
  fun arg ->
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
      let stored = Sys.getenv_opt key in
      if Option.is_some stored || Option.equal String.equal (Some "") stored
      then ()
      else Unix.putenv key value)
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

(* TODO [jerben] Consider memoizing this or any consumer functions *)
let environment_variables () = Unix.environment () |> Array.to_list |> envs_to_kv

let read schema =
  let data = environment_variables () in
  let data = List.map (fun (k, v) -> k, [ v ]) data in
  match Conformist.validate schema data with
  | [] ->
    (match Conformist.decode schema data with
    | Ok value -> value
    | Error msg ->
      Logs.err (fun m -> m "%s" msg);
      raise (Exception "Invalid configuration provided"))
  | errors ->
    let errors =
      List.map
        (fun (k, v) -> Format.sprintf "Configuration '%s' has invalid value: %s" k v)
        errors
    in
    List.iter (fun error -> Logs.err (fun m -> m "%s" error)) errors;
    raise (Exception "Invalid configuration provided")
;;

let read_string' key = Sys.getenv_opt key
let read_string = memoize read_string'

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

let is_testing () =
  match read_string "SIHL_ENV" with
  | Some "test" -> true
  | _ -> false
;;

let is_production () =
  match read_string "SIHL_ENV" with
  | Some "production" -> true
  | _ -> false
;;

let env_files_path () =
  match read_string "ENV_FILES_PATH" with
  | None | Some "" ->
    let markers = [ ".git"; ".hg"; ".svn"; ".bzr"; "_darcs" ] in
    let rec find_markers path_els =
      let path = String.concat "/" path_els in
      if List.exists (fun marker -> Sys.file_exists (path ^ "/" ^ marker)) markers
      then (
        (* Path found => Write it into the env var to "memoize" it *)
        Unix.putenv "ENV_FILES_PATH" path;
        Some path)
      else (
        match path_els with
        | [] -> None
        | _ -> find_markers @@ CCList.take (List.length path_els - 1) path_els)
    in
    find_markers @@ String.split_on_char '/' (Unix.getcwd ())
  | Some path -> Some path
;;

let read_env_file () =
  match env_files_path () with
  | Some path ->
    let filename = path ^ "/" ^ if is_testing () then ".env.test" else ".env" in
    let* exists = Lwt_unix.file_exists filename in
    if exists
    then (
      Logs.info (fun m -> m "Env file found: %s" filename);
      let* file = Lwt_io.open_file ~mode:Lwt_io.Input filename in
      let rec read_to_end file ls =
        let* line = Lwt_io.read_line_opt file in
        match line with
        | Some line -> read_to_end file (line :: ls)
        | None -> Lwt.return ls
      in
      let* envs = read_to_end file [] in
      envs |> envs_to_kv |> Option.some |> Lwt.return)
    else (
      Logs.debug (fun m -> m "Env file not found: %s. Continuing without it." filename);
      Lwt.return None)
  | None ->
    Logs.debug (fun m ->
        m
          "No env files directory found, please provide your own directory path with \
           environment variable ENV_FILES_PATH if you would like to use env files");
    Lwt.return None
;;

let require validators =
  let vars = environment_variables () in
  let errors = validators |> List.map (fun validator -> validator vars) |> List.concat in
  match errors with
  | (k, v) :: _ ->
    raise
    @@ Exception (Format.sprintf "For configuration key %s there is an issue: %s" k v)
  | _ -> ()
;;

(* TODO [jerben] Implement "print configuration documentation" commands *)
let commands _ = []
