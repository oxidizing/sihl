open Base
module Service = Config_service
include Config_core

type t = (string, string, String.comparator_witness) Map.t

module State : sig
  val set : t -> unit

  val get : unit -> t
end = struct
  let state = ref None

  let set config = state := Some config

  let get () =
    Option.value_exn
      ~message:"no configuration found, have you called Project.start()?" !state
end

let read_by_env setting =
  match Sys.getenv "SIHL_ENV" |> Option.value ~default:"development" with
  | "production" -> production setting
  | "test" -> test setting
  | _ -> development setting

let is_testing () =
  Sys.getenv "SIHL_ENV"
  |> Option.value ~default:"development"
  |> String.equal "test"

let of_list kvs =
  match Map.of_alist (module String) kvs with
  | `Duplicate_key msg ->
      Error ("duplicate key detected while creating configuration: " ^ msg)
  | `Ok map -> Ok map

let read_string ?default key =
  let value =
    Option.first_some (Map.find (State.get ()) key) (Sys.getenv key)
  in
  match (default, value) with
  | _, Some value -> value
  | Some default, None -> default
  | None, None -> failwith @@ "configuration " ^ key ^ " not found"

let read_int ?default key =
  let value =
    Option.first_some (Map.find (State.get ()) key) (Sys.getenv key)
  in
  match (default, value) with
  | _, Some value -> (
      match Option.try_with (fun () -> Base.Int.of_string value) with
      | Some value -> value
      | None -> failwith @@ "configuration " ^ key ^ " is not a int" )
  | Some default, None -> default
  | None, None -> failwith @@ "configuration " ^ key ^ " not found"

let read_bool ?default key =
  let value =
    Option.first_some (Map.find (State.get ()) key) (Sys.getenv key)
  in
  match (default, value) with
  | _, Some value -> (
      match Caml.bool_of_string_opt value with
      | Some value -> value
      | None -> failwith @@ "configuration " ^ key ^ " is not a int" )
  | Some default, None -> default
  | None, None -> failwith @@ "configuration " ^ key ^ " not found"

let register_config _ _ = Lwt_result.fail "TODO register_config"
