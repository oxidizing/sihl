module Model = Sihl__model.Model

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

type filter =
  | Filter of
      { op : op
      ; join : string list
      ; field_name : string
      ; value : Yojson.Safe.t
      }
  | And of filter list
  | Or of filter list
[@@deriving show, eq]

type select =
  { filter : filter option
  ; order_by : order_by list
  ; limit : int option
  ; offset : int option
  }
[@@deriving show, eq]

type 'a read = [ `Select of 'a Model.t * select ]

type 'a write =
  [ `Insert of 'a Model.t * 'a
  | `Update of 'a Model.t * 'a
  ]

type 'a t =
  [ 'a read
  | 'a write
  ]
