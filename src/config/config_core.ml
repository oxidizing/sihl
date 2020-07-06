open Base

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

  val of_list : Config.key_value list -> (t, string) Result.t

  val read_by_env : Config.t -> Config.key_value list

  val register : Config.t -> (unit, string) Result.t

  val get : unit -> t
end = struct
  type t = (string, string, String.comparator_witness) Map.t

  let state : t option ref = ref None

  let of_list kvs =
    match Map.of_alist (module String) kvs with
    | `Duplicate_key msg ->
        Error
          ("CONFIG: Duplicate key detected while creating configuration: " ^ msg)
    | `Ok map -> Ok map

  let read_by_env setting =
    match Sys.getenv "SIHL_ENV" |> Option.value ~default:"development" with
    | "production" -> Config.production setting
    | "test" -> Config.test setting
    | _ -> Config.development setting

  let register config =
    let config = config |> read_by_env |> of_list in
    match (config, !state) with
    | Ok config, None -> Ok (state := Some config)
    | Ok _, Some _ ->
        Error "CONFIG: There were already configurations registered"
    | Error msg, _ -> Error msg

  let get () =
    Option.value_exn
      ~message:
        "CONFIG: No configuration found, have you registered configurations \
         with Sihl.Config.register_config?"
      !state
end
