type op =
  | Eq
  | Gt
  | Lt
  | Like
[@@deriving show, eq]

type order_by =
  | Desc of string
  | Asc of string
[@@deriving show, eq]

let asc field = Asc field
let desc field = Desc field

type limit_offset =
  { limit : int
  ; offset : int
  }
[@@deriving show, eq]

type filter =
  | Filter of
      { op : op
      ; join : string list
      ; field_name : string
      ; value : string
      }
  | And of filter list
  | Or of filter list
[@@deriving show, eq]

type select = [ `Select of filter option * order_by list * limit_offset option ]
[@@deriving show, eq]

type 'a select_query = 'a Model.schema * select [@@deriving show, eq]

type 'a t = 'a Model.schema * [ `Insert of 'a | `Update of 'a | select ]
[@@deriving show, eq]

(* TODO Consider having model records without ID, and pass around (int, model)
   if there is an id *)
let insert (type a) (schema : a Model.schema) (model : a) : a t =
  schema, `Insert model
;;

let execute (conn : Caqti_lwt.connection) (query : 'a t) : unit Lwt.t =
  conn |> ignore;
  query |> ignore;
  Lwt.return ()
;;

let all (type a) (model : a Model.schema) : a select_query =
  model, `Select (None, [], None)
;;

let eq : op = Eq
let like : op = Like

let and_where
    ?(join : string list = [])
    (field : ('perm, 'a, 'field) Model.record_field)
    (op : op)
    (value : 'field)
    (query : 'b select_query)
    : 'b select_query
  =
  field |> ignore;
  op |> ignore;
  value |> ignore;
  join |> ignore;
  query
;;

let or_
    (type a)
    (wheres : (a select_query -> a select_query) list)
    (query : a select_query)
    : a select_query
  =
  List.fold_left (fun a b -> b a) query wheres
;;

let order_by (type a) (order_by : order_by list) (query : a select_query)
    : a Model.schema * select
  =
  order_by |> ignore;
  query
;;

let limit (limit : int) (query : 'a select_query) : 'a select_query =
  limit |> ignore;
  query
;;

let offset (offset : int) (query : 'a select_query) : 'a select_query =
  offset |> ignore;
  query
;;

let find (type a) (conn : Caqti_lwt.connection) (query : select) : a Lwt.t =
  conn |> ignore;
  query |> ignore;
  Obj.magic ()
;;

let table (name : string) =
  name |> ignore;
  Obj.magic ()
;;
