open Base

module Setting = struct
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

module Schema = struct
  module Type = struct
    type 'a condition = Default of 'a | RequiredIf of string * string | None

    type choices = string list

    type t =
      | String of string * string condition * choices
      | Int of string * int condition
      | Bool of string * bool condition

    let key type_ =
      match type_ with
      | String (key, _, _) -> key
      | Int (key, _) -> key
      | Bool (key, _) -> key

    let validate_string ~key ~value ~choices =
      let is_in_choices =
        List.find choices ~f:(fun choice -> String.equal choice value)
        |> Option.is_some
      in
      let is_choices_valid = List.is_empty choices || is_in_choices in
      let choices = String.concat ~sep:", " choices in
      if is_choices_valid then Ok ()
      else
        Error
          [%string
            {|value not found in choices key=$(key), value=$(value), choices=$(choices)|}]

    let does_required_config_exist ~required_key ~required_value ~config =
      Option.value_map (Map.find config required_key) ~default:false
        ~f:(fun v -> String.equal v required_value)

    let validate type_ config =
      let key = key type_ in
      let value = Map.find config key in
      match (type_, value) with
      | String (_, Default _, _), Some _ -> Ok ()
      | String (_, Default _, _), None -> Ok ()
      | String (_, RequiredIf (required_key, required_value), choices), value
        -> (
          let does_required_config_exist =
            does_required_config_exist ~required_key ~required_value ~config
          in
          match (does_required_config_exist, value) with
          | true, Some value -> validate_string ~key ~value ~choices
          | true, None ->
              Error
                [%string
                  {|required configuration because of dependency not found required_config=($(required_key), $(required_value)), key=$(key)|}]
          | false, _ -> Ok () )
      | String (_, None, choices), Some value ->
          validate_string ~key ~value ~choices
      | String (_, None, _), None ->
          Error [%string {|required configuration not provided key=$(key)|}]
      | Int (_, _), Some value ->
          Option.try_with (fun () -> value |> Base.Int.of_string)
          |> Result.of_option
               ~error:
                 [%string
                   {|provided configuration is not an int key=$(key), value=$(value)|}]
          |> Result.map ~f:(fun _ -> ())
      | Int (_, None), None ->
          Error [%string {|required configuration not provided key=$(key)|}]
      | Int (_, Default _), None -> Ok ()
      | Int (_, RequiredIf (required_key, required_value)), _ ->
          Map.find config required_key
          |> Result.of_option
               ~error:
                 [%string
                   {|provided configuration is not an int key=$(key), value=$(required_value)|}]
          |> Result.map ~f:(fun _ -> ())
      | Bool (_, _), Some value ->
          Option.try_with (fun () -> value |> Base.Bool.of_string)
          |> Result.of_option
               ~error:
                 [%string
                   {|provided configuration is not a bool key=$(key), value=$(value)|}]
          |> Result.map ~f:(fun _ -> ())
      | Bool (_, Default _), None -> Ok ()
      | Bool (_, RequiredIf (required_key, required_value)), None ->
          Map.find config required_key
          |> Result.of_option
               ~error:
                 [%string
                   {|provided configuration is not an int key=$(key), value=$(required_value)|}]
          |> Result.map ~f:(fun _ -> ())
      | Bool (_, None), None ->
          Error [%string {|required configuration is not provided key=$(key)|}]
  end

  type t = Type.t list

  let keys schema = schema |> List.map ~f:Type.key

  let condition required_if default =
    match (required_if, default) with
    | _, Some default -> Type.Default default
    | Some (key, value), _ -> Type.RequiredIf (key, value)
    | _ -> Type.None

  let string_ ?required_if ?default ?choices key =
    Type.String
      (key, condition required_if default, Option.value ~default:[] choices)

  let int_ ?required_if ?default key =
    Type.Int (key, condition required_if default)

  let bool_ ?required_if ?default key =
    Type.Bool (key, condition required_if default)
end

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

let of_list kvs =
  match Map.of_alist (module String) kvs with
  | `Duplicate_key msg ->
      Error ("duplicate key detected while creating configuration: " ^ msg)
  | `Ok map -> Ok map

(* overwrite config values with values from the environment *)
let merge_with_env config schema =
  let config_keys = Map.keys config in
  let schema_keys = schema |> List.map ~f:Schema.Type.key in
  let keys = List.concat [ config_keys; schema_keys ] in
  let rec merge keys result =
    match keys with
    | [] -> result
    | key :: keys -> (
        match Sys.getenv key with
        | Some value -> merge keys @@ Map.set ~key ~data:value result
        | None -> merge keys result )
  in
  merge keys config

let read_by_env setting =
  match Sys.getenv "SIHL_ENV" |> Option.value ~default:"development" with
  | "production" -> Setting.production setting
  | "test" -> Setting.test setting
  | _ -> Setting.development setting

let is_testing () =
  Sys.getenv "SIHL_ENV"
  |> Option.value ~default:"development"
  |> String.equal "test"

let process schemas setting =
  (* TODO add default values to config *)
  let setting = read_by_env setting |> of_list |> Result.ok_or_failwith in
  let schema = List.concat schemas in
  let config = merge_with_env setting schema in
  let rec check_types schema =
    match schema with
    | [] -> Ok ()
    | type_ :: schema ->
        Schema.Type.validate type_ config
        |> Result.bind ~f:(fun _ -> check_types schema)
  in
  check_types schema |> Result.map ~f:(fun _ -> config)

let load_config schemas setting =
  process schemas setting |> Core_err.with_configuration |> State.set |> ignore

let read_string ?default key =
  let value =
    Option.first_some (Map.find (State.get ()) key) (Sys.getenv key)
  in
  match (default, value) with
  | _, Some value -> value
  | Some default, None -> default
  | None, None ->
      Core_err.raise_configuration @@ "configuration " ^ key ^ " not found"

let read_int ?default key =
  let value =
    Option.first_some (Map.find (State.get ()) key) (Sys.getenv key)
  in
  match (default, value) with
  | _, Some value -> (
      match Option.try_with (fun () -> Base.Int.of_string value) with
      | Some value -> value
      | None ->
          Core_err.raise_configuration @@ "configuration " ^ key
          ^ " is not a int" )
  | Some default, None -> default
  | None, None ->
      Core_err.raise_configuration @@ "configuration " ^ key ^ " not found"

let read_bool ?default key =
  let value =
    Option.first_some (Map.find (State.get ()) key) (Sys.getenv key)
  in
  match (default, value) with
  | _, Some value -> (
      match Caml.bool_of_string_opt value with
      | Some value -> value
      | None ->
          Core_err.raise_configuration @@ "configuration " ^ key
          ^ " is not a int" )
  | Some default, None -> default
  | None, None ->
      Core_err.raise_configuration @@ "configuration " ^ key ^ " not found"
