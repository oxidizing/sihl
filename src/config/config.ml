module Service = Config_service
module Sig = Config_sig

type t = Config_core.Config.t

let create = Config_core.Config.create

(* TODO [jerben] Remove these two and explicitly inject config service where those are used *)
let is_testing () =
  let open Base in
  Sys.getenv "SIHL_ENV"
  |> Option.value ~default:"development"
  |> String.equal "test"

let read_string_default ~default key =
  let open Base in
  let value =
    Option.first_some (Sys.getenv key)
      (Map.find (Config_core.Internal.get ()) key)
  in
  Option.value value ~default
