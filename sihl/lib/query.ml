type 'a t =
  [ `Insert of 'a Model.schema * 'a
  | `Update of 'a Model.schema * 'a
  | `Select of 'a Model.schema
  ]

let insert (type a) (schema : a Model.schema) (model : a) : a t =
  `Insert (schema, model)
;;

let execute (conn : Caqti_lwt.connection) (query : 'a t) : unit Lwt.t =
  conn |> ignore;
  query |> ignore;
  Lwt.return ()
;;

let query (model : 'a Model.schema) : [ `Select of 'a ] =
  model |> ignore;
  Obj.magic ()
;;

type op =
  | Eq
  | Gt
  | Lt
  | Lk

let eq : op = Eq

let where
    (type a)
    (field : ('perm, a, 'field) Model.record_field)
    (op : op)
    (value : 'field)
    (query : [ `Select of a ])
    : a t
  =
  field |> ignore;
  op |> ignore;
  value |> ignore;
  query |> ignore;
  Obj.magic ()
;;

let find (conn : Caqti_lwt.connection) (query : 'a t) : 'a Lwt.t =
  conn |> ignore;
  query |> ignore;
  Obj.magic ()
;;
