type op =
  | Eq
  | Gt
  | Lt
  | Lk

type order_by_op =
  | Desc
  | Asc

type order_by = (order_by_op * string) list

type limit_offset =
  { limit : int
  ; offset : int
  }

type filter =
  | Filter of
      { op : op
      ; field_name : string
      ; value : string
      }
  | And of filter list
  | Or of filter list

type 'a t =
  [ `Insert of 'a Model.schema * 'a
  | `Update of 'a Model.schema * 'a
  | `Select of 'a Model.schema * filter * order_by * limit_offset
  ]

(* TODO Consider having model records without ID, and pass around (int, model)
   if there is an id *)
let insert (type a) (schema : a Model.schema) (model : a) : a t =
  `Insert (schema, model)
;;

let execute (conn : Caqti_lwt.connection) (query : 'a t) : unit Lwt.t =
  conn |> ignore;
  query |> ignore;
  Lwt.return ()
;;

let query (type a) (model : a Model.schema) : [ `Select of a Model.schema ] =
  `Select model
;;

let eq : op = Eq

let where
    (type a)
    (field : ('perm, a, 'field) Model.record_field)
    (op : op)
    (value : 'field)
    (query : [ `Select of a Model.schema ])
    : [ `Select of a Model.schema ]
  =
  field |> ignore;
  op |> ignore;
  value |> ignore;
  query
;;

let find
    (type a)
    (conn : Caqti_lwt.connection)
    (query : [ `Select of a Model.schema ])
    : a Lwt.t
  =
  conn |> ignore;
  query |> ignore;
  Obj.magic ()
;;
