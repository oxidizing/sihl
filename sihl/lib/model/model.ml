module Ptime = struct
  include Ptime

  let to_yojson ptime = `String (Ptime.to_rfc3339 ptime)

  let of_yojson json =
    match json with
    | `String string ->
      (match Ptime.of_rfc3339 string with
      | Ok (ptime, _, _) -> Ok ptime
      | Error _ -> Error (Format.sprintf "Invalid ptime provided %s" string))
    | json ->
      Error (Format.sprintf "Invalid ptime provided %s" (Yojson.Safe.show json))
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

type meta = { nullable : bool }
type 'a model_field = meta * 'a type_field
type field = AnyField : string * 'a model_field -> field

type primary_key = (* TODO support UUID as well *)
  | Serial of string

type ('a, 'field) record =
  { to_yojson : 'a -> Yojson.Safe.t
  ; of_yojson : Yojson.Safe.t -> ('a, string) Result.t
  ; name : string
  ; fields :
      'field list (* TODO delete field_names, can be derived from fields *)
  ; field_names : string list
  ; validate : 'a -> string list
  }

type 'a t = primary_key * ('a, field) record

type generic =
  { name : string
  ; pk : primary_key
  ; fields : field list
  }

type validation_error =
  { message : string
  ; code : string option
  ; params : (string * string) list
  }

type invalid = string list * (string * validation_error list) list

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
(*   match (field : field) with *)
(*   | AnyField (name, field) -> *)
(*     (match field with *)
(*     | Integer -> () *)
(*     | Email -> ()) *)
(* ;; *)

let foreign_key
    ?(nullable = false)
    (on_delete : fk_on_delete)
    (model_name : string)
    (record_field : ('perm, 'record, int) record_field)
  =
  let field = { nullable }, Foreign_key { model_name; on_delete } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let int
    ?default
    ?(nullable = false)
    (record_field : ('perm, 'record, int) record_field)
  =
  let field = { nullable }, Integer { default } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let bool
    ?(default = false)
    ?(nullable = false)
    (record_field : ('perm, 'record, bool) record_field)
  =
  let field = { nullable }, Boolean { default } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let enum
    (type a)
    ?default
    ?(nullable = false)
    (of_yojson : Yojson.Safe.t -> (a, string) Result.t)
    (to_yojson : a -> Yojson.Safe.t)
    (record_field : ('perm, 'record, 'a) record_field)
  =
  let field = { nullable }, Enum { of_yojson; to_yojson; default } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let email
    ?default
    ?(nullable = false)
    (record_field : ('perm, 'record, 'a) record_field)
  =
  let field = { nullable }, Email { default } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let string
    ?default
    ?max_length
    ?(nullable = false)
    (record_field : ('perm, 'record, 'a) record_field)
  =
  let field = { nullable }, String { max_length; default } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let timestamp
    ?(nullable = false)
    ?default
    ?(update = false)
    (record_field : ('perm, 'record, 'a) record_field)
  =
  let field = { nullable }, Timestamp { default; update } in
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let generic (t : 'a t) : generic =
  let pk, record = t in
  { name = record.name; pk; fields = record.fields }
;;

let equal _ _ _ = true

let validate_model (model : 'a t) : 'a t =
  let _, record = model in
  let schema_names = List.map field_name record.fields in
  let field_names = record.field_names in
  if CCList.equal
       String.equal
       (CCList.sort compare schema_names)
       (CCList.sort compare field_names)
  then model
  else
    failwith
    @@ Format.sprintf
         "you did not list all fields of the model '%s' in the schema"
         record.name
;;

let create
    ?(pk = Serial "id")
    ?(validate = fun _ -> [])
    to_yojson
    of_yojson
    (name : string)
    (fields : string list)
    (schema : field list)
    : 'a t
  =
  let model =
    ( pk
    , { name
      ; fields = schema
      ; field_names = fields
      ; to_yojson
      ; of_yojson
      ; validate
      } )
    |> validate_model
  in
  if Hashtbl.mem models name
  then failwith @@ Format.sprintf "a model '%s' was already defined" name
  else Hashtbl.add models name (generic model);
  model
;;

let validate_field (field : field * Yojson.Safe.t)
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

let field_data (model : 'a t) (fields : (string * Yojson.Safe.t) list)
    : ((field * Yojson.Safe.t) list, string) Result.t
  =
  let _, record = model in
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
  loop record.fields fields []
;;

let fields (type a) (model : a t) (v : a) : (field * Yojson.Safe.t) list =
  let _, record = model in
  match record.to_yojson v with
  | `Assoc actual_fields ->
    (match field_data model actual_fields with
    | Ok fields -> fields
    | Error msg -> failwith msg)
  | _ ->
    failwith
    @@ Format.sprintf "provided data for model %s is not a record" record.name
;;

let validate (type a) (model : a t) (v : a) : invalid =
  let _, record = model in
  let model_errors = record.validate v in
  match record.to_yojson v with
  | `Assoc actual_fields ->
    (match field_data model actual_fields with
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

let pp (type a) (model : a t) (formatter : Format.formatter) (v : a) : unit =
  let _, record = model in
  v |> record.to_yojson |> Yojson.Safe.pp formatter
;;

let eq (type a) (model : a t) (a : a) (b : a) : bool =
  let _, record = model in
  Yojson.Safe.equal (record.to_yojson a) (record.to_yojson b)
;;

let field_int (name : string) : ('perm, 'a, int) record_field =
  Fieldslib.Field.Field
    { force_variance = (fun _ -> ())
    ; name
    ; setter = None
    ; getter = (fun _ -> 0)
    ; fset = (fun a _ -> a)
    }
;;

let field_bool (name : string) : ('perm, 'a, bool) record_field =
  Fieldslib.Field.Field
    { force_variance = (fun _ -> ())
    ; name
    ; setter = None
    ; getter = (fun _ -> false)
    ; fset = (fun a _ -> a)
    }
;;

let field_string (name : string) : ('perm, 'a, string) record_field =
  Fieldslib.Field.Field
    { force_variance = (fun _ -> ())
    ; name
    ; setter = None
    ; getter = (fun _ -> "")
    ; fset = (fun a _ -> a)
    }
;;

let field_ptime (name : string) : ('perm, 'a, Ptime.t) record_field =
  Fieldslib.Field.Field
    { force_variance = (fun _ -> ())
    ; name
    ; setter = None
    ; getter = (fun _ -> Ptime_clock.now ())
    ; fset = (fun a _ -> a)
    }
;;
