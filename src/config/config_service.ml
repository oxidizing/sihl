open Base

module Make (Log : Log_sig.SERVICE) : Config_sig.SERVICE = struct
  let lifecycle =
    Core.Container.Lifecycle.make "config"
      (fun ctx -> Lwt.return ctx)
      (fun _ -> Lwt.return ())

  let register_config _ config =
    Log.debug (fun m -> m "CONFIG: Register config");
    Config_core.Internal.register config |> Lwt.return

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
    | _, Some value -> value
    | Some default, None -> default
    | None, None ->
        raise
          (Config_core.Exception
             (Printf.sprintf "CONFIG: Configuration %s not found" key))

  let read_int ?default key =
    let value =
      Option.first_some (Sys.getenv key)
        (Map.find (Config_core.Internal.get ()) key)
    in
    match (default, value) with
    | _, Some value -> (
        match Option.try_with (fun () -> Base.Int.of_string value) with
        | Some value -> value
        | None ->
            raise
              (Config_core.Exception
                 (Printf.sprintf "CONFIG: Configuration %s is not a int" key)) )
    | Some default, None -> default
    | None, None ->
        raise
          (Config_core.Exception
             (Printf.sprintf "CONFIG: Configuration %s not found" key))

  let read_bool ?default key =
    let value =
      Option.first_some (Sys.getenv key)
        (Map.find (Config_core.Internal.get ()) key)
    in
    match (default, value) with
    | _, Some value -> (
        match Caml.bool_of_string_opt value with
        | Some value -> value
        | None ->
            raise
              (Config_core.Exception
                 (Printf.sprintf "CONFIG: Configuration %s is not a int" key)) )
    | Some default, None -> default
    | None, None ->
        raise
          (Config_core.Exception
             (Printf.sprintf "CONFIG: Configuration %s not found" key))
end
