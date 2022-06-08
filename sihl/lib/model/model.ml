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

type ('perm, 'record, 'field) record_field =
  ('perm, 'record, 'field) Fieldslib.Field.t_with_perm

type 'a validator = 'a -> (unit, string) Result.t

type timestamp_default =
  | Fn of (unit -> Ptime.t)
  | Now

type fk_on_delete =
  | Cascade
  | Set_null
  | Set_default

type _ type_field =
  | Integer : { default : int option } -> int type_field
  | Boolean : { default : bool } -> bool type_field
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
  | Foreign_key :
      { model_name : string
      ; on_delete : fk_on_delete
      }
      -> int type_field
  | Enum :
      { of_yojson : Yojson.Safe.t -> ('a, string) Result.t
      ; to_yojson : 'a -> Yojson.Safe.t
      ; default : 'a option
      }
      -> 'a type_field

type field_meta =
  { primary_key : bool
  ; nullable : bool
  }

type 'a field = field_meta * 'a type_field
type any_field = AnyField : string * 'a field -> any_field

type 'a t =
  { to_yojson : 'a -> Yojson.Safe.t
  ; of_yojson : Yojson.Safe.t -> ('a, string) Result.t
  ; name : string
  ; fields : any_field list
  ; field_names : string list
  ; validate : 'a -> string list
  }

type generic =
  { name : string
  ; fields : any_field list
  }

type validation_error =
  { message : string
  ; code : string option
  ; params : (string * string) list
  }

type model_validation = string list * (string * validation_error list) list

let models : (string, generic) Hashtbl.t = Hashtbl.create 100
let field_name (AnyField (name, _)) = name

let is_foreign_key = function
  | AnyField (_, (_, Foreign_key _)) -> true
  | _ -> false
;;

(* TODO implement using of_list and only once we need model plotting *)
(* let graph () : (generic, unit) CCGraph.t = *)
(*   let graph_tbl : (generic, generic) Hashtbl.t = Hashtbl.create 0 in *)
(*   models *)
(*   |> Hashtbl.iter (fun _ model -> *)
(*          model.fields *)
(*          |> List.filter is_foreign_key *)
(*          |> List.iter (function *)
(*                 | AnyField (name, (_, Foreign_key _)) -> *)
(*                   Hashtbl.add graph_tbl model @@ Hashtbl.find models name *)
(*                 | _ -> ())); *)
(*   let graph : (generic, generic list) Hashtbl.t = Hashtbl.create 100 in *)
(*   graph *)
(*   |> Hashtbl.to_seq_keys *)
(* |> Seq.iter (fun k -> Hashtbl.find_all graph_tbl k |> Hashtbl.add graph
   k); *)
(*   CCGraph.of_hashtbl graph *)
(* ;; *)

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
    (on_delete : fk_on_delete)
    (model_name : string)
    (record_field : ('perm, 'record, int) record_field)
  =
  let field =
    { primary_key; nullable }, Foreign_key { model_name; on_delete }
  in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let int
    ?default
    ?(primary_key = false)
    ?(nullable = false)
    (record_field : ('perm, 'record, int) record_field)
  =
  let field = { primary_key; nullable }, Integer { default } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let bool
    ?(default = false)
    ?(primary_key = false)
    ?(nullable = false)
    (record_field : ('perm, 'record, bool) record_field)
  =
  let field = { primary_key; nullable }, Boolean { default } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let enum
    (type a)
    ?default
    ?(primary_key = false)
    ?(nullable = false)
    (of_yojson : Yojson.Safe.t -> (a, string) Result.t)
    (to_yojson : a -> Yojson.Safe.t)
    (record_field : ('perm, 'record, 'a) record_field)
  =
  let field =
    { primary_key; nullable }, Enum { of_yojson; to_yojson; default }
  in
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

let generic (t : 'a t) : generic = { name = t.name; fields = t.fields }
let equal _ _ _ = true

let validate_model (schema : 'a t) : 'a t =
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
         "you did not list all fields of the model '%s' in the schema"
         schema.name
;;

let create
    ?(validate = fun _ -> [])
    to_yojson
    of_yojson
    (name : string)
    (fields : string list)
    (schema : any_field list)
    : 'a t
  =
  let model =
    { name
    ; fields = schema
    ; field_names = fields
    ; to_yojson
    ; of_yojson
    ; validate
    }
    |> validate_model
  in
  if Hashtbl.mem models name
  then failwith @@ Format.sprintf "a model '%s' was already defined" name
  else Hashtbl.add models name (generic model);
  model
;;

let validate_field (field : any_field * Yojson.Safe.t)
    : (string * validation_error list) option
  =
  (* TODO finish implementing field validation *)
  match field with
  | AnyField (_, (_, Integer _)), `Int _ -> None
  | AnyField (n, (_, String { max_length; _ })), `String v ->
    if String.length v > Option.value ~default:255 max_length
    then
      Some
        ( n (* TODO look into ocaml-gettext, we might be able to use %s *)
        , [ { message = "%s is too long"
            ; code = Some "too long"
            ; params = [ "field", n ]
            }
          ] )
    else None
  | _ -> None
;;

let field_data (schema : 'a t) (fields : (string * Yojson.Safe.t) list)
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

let validate (type a) (schema : a t) (model : a) : model_validation =
  let model_errors = schema.validate model in
  match schema.to_yojson model with
  | `Assoc actual_fields ->
    (match field_data schema actual_fields with
    | Ok fields ->
      let field_errors =
        fields
        |> List.map validate_field
        |> List.map CCOption.to_list
        |> List.concat
      in
      model_errors, field_errors
    | Error msg -> [ msg ], [])
  | _ -> [ "provided data is not a record" ], []
;;

let pp (type a) (schema : a t) (formatter : Format.formatter) (model : a) : unit
  =
  model |> schema.to_yojson |> Yojson.Safe.pp formatter
;;

let eq (type a) (schema : a t) (a : a) (b : a) : bool =
  Yojson.Safe.equal (schema.to_yojson a) (schema.to_yojson b)
;;
