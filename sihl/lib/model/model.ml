module Ptime = struct
  include Ptime

  let to_yojson ptime = Yojson.Safe.from_string (Ptime.to_rfc3339 ptime)

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

type 'a valiator = 'a -> (unit, string) Result.t

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
  | Enum :
      ((Yojson.Safe.t -> ('a, string) Result.t) * ('a -> Yojson.Safe.t))
      -> 'a type_field

type field_meta =
  { primary_key : bool
  ; nullable : bool
  }

type 'a field = field_meta * 'a type_field
type any_field = AnyField : string * 'a field -> any_field

(* let foo field = *)
(*   match (field : any_field) with *)
(*   | AnyField (name, field) -> *)
(*     (match field with *)
(*     | Integer -> () *)
(*     | Email -> ()) *)
(* ;; *)

let field
    (type a)
    (record_field : ('perm, 'record, a) record_field)
    (field : a field)
  =
  let name = Fieldslib.Field.name record_field in
  AnyField (name, field)
;;

let int ?default ?(primary_key = false) ?(nullable = false) () =
  { primary_key; nullable }, Integer { default }
;;

let enum
    (type a)
    ?(primary_key = false)
    ?(nullable = false)
    (of_yojson : Yojson.Safe.t -> (a, string) Result.t)
    (to_yojson : a -> Yojson.Safe.t)
  =
  { primary_key; nullable }, Enum (of_yojson, to_yojson)
;;

let email ?default ?(primary_key = false) ?(nullable = false) () =
  { primary_key; nullable }, Email { default }
;;

let string ?default ?max_length ?(primary_key = false) ?(nullable = false) () =
  { primary_key; nullable }, String { max_length; default }
;;

let timestamp
    ?(primary_key = false)
    ?(nullable = false)
    ?default
    ?(update = false)
    ()
  =
  { primary_key; nullable }, Timestamp { default; update }
;;

type 'a schema =
  { to_yojson : 'a -> Yojson.Safe.t
  ; of_yojson : Yojson.Safe.t -> ('a, string) Result.t
  ; name : string
  ; fields : any_field list
  ; validate : 'a -> string list
  }

let create
    ~validate
    to_yojson
    of_yojson
    (name : string)
    (fields : string list)
    (schema : any_field list)
  =
  fields |> ignore;
  { name; fields = schema; to_yojson; of_yojson; validate }
;;
