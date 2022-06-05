module Ptime = struct
  include Ptime

  let to_yojson ptime = `String (Ptime.to_rfc3339 ptime)

  let of_yojson json =
    try
      match Ptime.of_rfc3339 @@ Yojson.Safe.to_string json with
      | Ok (ptime, _, _) -> Ok ptime
      | Error _ -> Error "Invalid ptime provided"
    with
    | _ -> Error "Could not parse ptime"
  ;;
end

type database =
  | Postgresql
  | Mariadb
  | Sqlite

let list_of_model = Obj.magic

module type MODEL = sig end

type 'a t = { model : unit }

type ('perm, 'record, 'field) record_field =
  ('perm, 'record, 'field) Fieldslib.Field.t_with_perm

type 'a validator = 'a -> (unit, string) Result.t

type timestamp_default =
  | Fn of (unit -> Ptime.t)
  | Now

type _ type_field =
  | Integer : { default : int option } -> int type_field
  | Email : { default : string option } -> string type_field
  | String :
      { max_length : int option
      ; default : string option
      }
      -> string type_field
  | Timestamp :
      { default : timestamp_default option
      ; update : bool
      }
      -> Ptime.t type_field
  | Foreign_key : { model_name : string } -> int type_field
  | Enum :
      ((Yojson.Safe.t -> ('a, string) Result.t) * ('a -> Yojson.Safe.t))
      -> 'a type_field

type field_meta =
  { primary_key : bool
  ; nullable : bool
  }

type 'a field = field_meta * 'a type_field
type any_field = AnyField : string * 'a field -> any_field

let field_name (AnyField (name, _)) = name

(* let foo field = *)
(*   match (field : any_field) with *)
(*   | AnyField (name, field) -> *)
(*     (match field with *)
(*     | Integer -> () *)
(*     | Email -> ()) *)
(* ;; *)

let foreign_key
    ?(primary_key = false)
    ?(nullable = false)
    (model_name : string)
    (record_field : ('perm, 'record, 'a) record_field)
  =
  let field = { primary_key; nullable }, Foreign_key { model_name } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let int
    ?default
    ?(primary_key = false)
    ?(nullable = false)
    (record_field : ('perm, 'record, 'a) record_field)
  =
  let field = { primary_key; nullable }, Integer { default } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let enum
    (type a)
    ?(primary_key = false)
    ?(nullable = false)
    (of_yojson : Yojson.Safe.t -> (a, string) Result.t)
    (to_yojson : a -> Yojson.Safe.t)
    (record_field : ('perm, 'record, 'a) record_field)
  =
  let field = { primary_key; nullable }, Enum (of_yojson, to_yojson) in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let email
    ?default
    ?(primary_key = false)
    ?(nullable = false)
    (record_field : ('perm, 'record, 'a) record_field)
  =
  let field = { primary_key; nullable }, Email { default } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let string
    ?default
    ?max_length
    ?(primary_key = false)
    ?(nullable = false)
    (record_field : ('perm, 'record, 'a) record_field)
  =
  let field = { primary_key; nullable }, String { max_length; default } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let timestamp
    ?(primary_key = false)
    ?(nullable = false)
    ?default
    ?(update = false)
    (record_field : ('perm, 'record, 'a) record_field)
  =
  let field = { primary_key; nullable }, Timestamp { default; update } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

type 'a schema =
  { to_yojson : 'a -> Yojson.Safe.t
  ; of_yojson : Yojson.Safe.t -> ('a, string) Result.t
  ; name : string
  ; fields : any_field list
  ; field_names : string list
  ; validate : 'a -> string list
  }

let validate_schema (schema : 'a schema) : 'a schema =
  let schema_names = List.map field_name schema.fields in
  let field_names = schema.field_names in
  if CCList.equal
       String.equal
       (CCList.sort compare schema_names)
       (CCList.sort compare field_names)
  then schema
  else
    failwith
    @@ Format.sprintf
         "you did not list all fields of the model %s in the schema"
         schema.name
;;

let create
    ~validate
    to_yojson
    of_yojson
    (name : string)
    (fields : string list)
    (schema : any_field list)
    : 'a schema
  =
  let schema =
    { name
    ; fields = schema
    ; field_names = fields
    ; to_yojson
    ; of_yojson
    ; validate
    }
  in
  validate_schema schema
;;

open Sexplib0.Sexp_conv

type validation_error =
  { message : string
  ; code : string option
  ; params : string * string list
  }
[@@deriving sexp]

let validate_field (field : any_field * Yojson.Safe.t)
    : (string * validation_error list) option
  =
  match field with
  | AnyField (_, (_, Integer _)), `Int _ -> None
  | _ -> None
;;

let field_data (schema : 'a schema) (fields : (string * Yojson.Safe.t) list)
    : ((any_field * Yojson.Safe.t) list, string) Result.t
  =
  let rec loop s_fields a_fields result =
    match s_fields, a_fields with
    | s :: _, [] -> Error (Format.sprintf "field %s not found" @@ field_name s)
    | s :: s_fields, a_fields ->
      let actual =
        List.find_opt (CCFun.compose fst @@ String.equal @@ field_name s) fields
      in
      (match actual with
      | Some (_, v) ->
        let a_fields = CCList.tail_opt a_fields |> Option.value ~default:[] in
        loop s_fields a_fields ((s, v) :: result)
      | None -> Error (Format.sprintf "field %s not found" @@ field_name s))
    | [], _ -> Ok result
  in
  loop schema.fields fields []
;;

type model_validation = string list * (string * validation_error list) list
[@@deriving sexp]

let compare_model_validation e1 e2 =
  String.compare
    (sexp_of_model_validation e1 |> Sexplib0.Sexp.to_string)
    (sexp_of_model_validation e2 |> Sexplib0.Sexp.to_string)
;;

let validate (type a) (schema : a schema) (model : a) : model_validation =
  let model_errors = schema.validate model in
  match schema.to_yojson model with
  | `Assoc actual_fields ->
    (match field_data schema actual_fields with
    | Ok fields ->
      let field_errors =
        List.map validate_field fields
        |> List.map CCOption.to_list
        |> List.concat
      in
      model_errors, field_errors
    | Error msg -> [ msg ], [])
  | _ -> [ "provided data is not a record" ], []
;;

let pp (type a) (schema : a schema) (formatter : Format.formatter) (model : a)
    : unit
  =
  model |> schema.to_yojson |> Yojson.Safe.pp formatter
;;

let eq (type a) (schema : a schema) (a : a) (b : a) : bool =
  Yojson.Safe.equal (schema.to_yojson a) (schema.to_yojson b)
;;
