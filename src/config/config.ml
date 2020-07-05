open Base
module Service = Config_service
include Config_core.Config

let register_config _ config =
  Config_core.Internal.register config |> Lwt.return

let is_testing () =
  Sys.getenv "SIHL_ENV"
  |> Option.value ~default:"development"
  |> String.equal "test"

let read_string ?default key =
  let value =
    Option.first_some
      (Map.find (Config_core.Internal.get ()) key)
      (Sys.getenv key)
  in
  match (default, value) with
  | _, Some value -> Ok value
  | Some default, None -> Ok default
  | None, None ->
      Error (Printf.sprintf "CONFIG: Configuration %s not found" key)

let read_int ?default key =
  let value =
    Option.first_some
      (Map.find (Config_core.Internal.get ()) key)
      (Sys.getenv key)
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
    Option.first_some
      (Map.find (Config_core.Internal.get ()) key)
      (Sys.getenv key)
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
