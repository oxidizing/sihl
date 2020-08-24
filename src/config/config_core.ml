open Base

exception Exception of string

module Config = struct
  type key_value = string * string

  type t = {
    development : key_value list;
    test : key_value list;
    production : key_value list;
  }

  let production setting = setting.production

  let development setting = setting.development

  let test setting = setting.test

  let create ~development ~test ~production = { development; test; production }
end

module Internal : sig
  type t = (string, string, String.comparator_witness) Map.t

  val of_list : Config.key_value list -> t

  val read_by_env : Config.t -> Config.key_value list

  val register : Config.t -> unit

  val get : unit -> t
end = struct
  type t = (string, string, String.comparator_witness) Map.t

  let state : t option ref = ref None

  let of_list kvs =
    match Map.of_alist (module String) kvs with
    | `Duplicate_key msg ->
        raise
          (Exception
             ( "CONFIG: Duplicate key detected while creating configuration: "
             ^ msg ))
    | `Ok map -> map

  let read_by_env setting =
    match Sys.getenv "SIHL_ENV" |> Option.value ~default:"development" with
    | "production" -> Config.production setting
    | "test" -> Config.test setting
    | _ -> Config.development setting

  let register config =
    let config = config |> read_by_env |> of_list in
    match !state with
    | None -> state := Some config
    | Some _ ->
        raise (Exception "CONFIG: There were already configurations registered")

  let get () =
    Option.value_exn
      ~message:
        "CONFIG: No configuration found, have you registered configurations \
         with Sihl.Config.register_config?"
      !state
end
