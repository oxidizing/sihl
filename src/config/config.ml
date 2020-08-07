open Base
module Service = Config_service
module Sig = Config_sig
include Config_core.Config

let create = Config_core.Config.create

let is_testing () =
  Sys.getenv "SIHL_ENV"
  |> Option.value ~default:"development"
  |> String.equal "test"

let is_production () =
  Sys.getenv "SIHL_ENV"
  |> Option.value ~default:"development"
  |> String.equal "production"

let read_string_default ~default key =
  let value =
    Option.first_some (Sys.getenv key)
      (Map.find (Config_core.Internal.get ()) key)
  in
  Option.value value ~default

let read_string ?default key =
  let value =
    Option.first_some (Sys.getenv key)
      (Map.find (Config_core.Internal.get ()) key)
  in
  match (default, value) with
  | _, Some value -> Ok value
  | Some default, None -> Ok default
  | None, None ->
      Error (Printf.sprintf "CONFIG: Configuration %s not found" key)

let read_int ?default key =
  let value =
    Option.first_some (Sys.getenv key)
      (Map.find (Config_core.Internal.get ()) key)
  in
  match (default, value) with
  | _, Some value -> (
      match Option.try_with (fun () -> Base.Int.of_string value) with
      | Some value -> Ok value
      | None ->
          Error (Printf.sprintf "CONFIG: Configuration %s is not a int" key) )
  | Some default, None -> Ok default
  | None, None ->
      Error (Printf.sprintf "CONFIG: Configuration %s not found" key)

let read_bool ?default key =
  let value =
    Option.first_some (Sys.getenv key)
      (Map.find (Config_core.Internal.get ()) key)
  in
  match (default, value) with
  | _, Some value -> (
      match Caml.bool_of_string_opt value with
      | Some value -> Ok value
      | None ->
          Error (Printf.sprintf "CONFIG: Configuration %s is not a int" key) )
  | Some default, None -> Ok default
  | None, None ->
      Error (Printf.sprintf "CONFIG: Configuration %s not found" key)
