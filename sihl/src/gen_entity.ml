let template =
  {|
type t =
  { id : string
  {{entity_type}}
  ; created_at : Ptime.t
  ; updated_at : Ptime.t
  }
[@@deriving show]

let create {{create_args}} =
  let now = Ptime_clock.now () in
  let id = Sihl.Random.Uuid.create () in
  { id; {{created_value}} created_at = now; updated_at = now }
;;

let[@warning "-45"] schema
    : (unit, {{ctor_type}} -> t, t) Conformist.t
  =
  Conformist.(
    make
      Field.[
        {{conformist_fields}}
        ]
      create)
;;
|}
;;

let entity_type (schema : Gen_core.schema) =
  schema
  |> List.map (fun (name, type_) ->
    Format.sprintf "%s: %s" name (Gen_core.ocaml_type_of_gen_type type_))
  |> String.concat ";"
  |> Format.sprintf ";%s"
;;

let ctor_type (schema : Gen_core.schema) =
  schema
  |> List.map snd
  |> List.map Gen_core.ocaml_type_of_gen_type
  |> String.concat " -> "
;;

let create_args (schema : Gen_core.schema) =
  schema |> List.map fst |> String.concat " "
;;

let created_value (schema : Gen_core.schema) =
  schema |> List.map fst |> List.map (Format.sprintf "%s;") |> String.concat " "
;;

let conformist_fields (schema : Gen_core.schema) =
  schema
  |> List.map (fun (name, type_) ->
    Format.sprintf {|%s "%s"|} (Gen_core.conformist_type_of_gen_type type_) name)
  |> String.concat "; "
;;

let file (schema : Gen_core.schema) =
  let params =
    [ "entity_type", entity_type schema
    ; "create_args", create_args schema
    ; "created_value", created_value schema
    ; "ctor_type", ctor_type schema
    ; "conformist_fields", conformist_fields schema
    ]
  in
  Gen_core.{ name = "entity.ml"; template; params }
;;
