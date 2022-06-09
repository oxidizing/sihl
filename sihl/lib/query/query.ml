module Sql = Query_sql

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

type select =
  { filter : filter option
  ; order_by : order_by list
  ; pagination : limit_offset option
  }
[@@deriving show, eq]

type 'a read = 'a Model.t * select
type 'a write = [ `Insert of 'a * 'a Model.t ]

(* TODO Consider having model records without ID, and pass around (int, model)
   if there is an id *)
let insert
    (type a)
    (model : a Model.t)
    (v : a)
    ((module Db : Caqti_lwt.CONNECTION) : Caqti_lwt.connection)
    : int Lwt.t
  =
  let r = Sql.insert (Config.database ()) model in
  Db.find r v |> Lwt_result.map_err Caqti_error.show |> Lwt.map CCResult.get_exn
;;

let all (type a) (model : a Model.t) : a read =
  model, { filter = None; order_by = []; pagination = None }
;;

let eq : op = Eq
let like : op = Like

let and_where
    ?(join : string list = [])
    (field : ('perm, 'a, 'field) Model.record_field)
    (op : op)
    (value : 'field)
    (query : 'b read)
    : 'b read
  =
  field |> ignore;
  op |> ignore;
  value |> ignore;
  join |> ignore;
  query
;;

let or_ (type a) (wheres : (a read -> a read) list) (query : a read) : a read =
  List.fold_left (fun a b -> b a) query wheres
;;

let order_by (type a) (order_by : order_by list) (query : a read)
    : a Model.t * select
  =
  order_by |> ignore;
  query
;;

let limit (limit : int) (query : 'a read) : 'a read =
  limit |> ignore;
  query
;;

let offset (offset : int) (query : 'a read) : 'a read =
  offset |> ignore;
  query
;;

let find (type a) (conn : Caqti_lwt.connection) (query : a read)
    : (int * a) Lwt.t
  =
  conn |> ignore;
  query |> ignore;
  failwith "fooooooooooooooooooooooooooooooooooooo"
;;

let model (name : string) =
  name |> ignore;
  failwith "model"
;;

module Dynparam = struct
  type t = Pack : 'a Caqti_type.t * 'a -> t

  let show (t : t) : string =
    match t with
    | Pack (_, _) -> "hello"
  ;;

  let empty = Pack (Caqti_type.unit, ())
  let add t x (Pack (t', x')) = Pack (Caqti_type.tup2 t' t, (x', x))
end

let to_caqti (query : 'a read) : string =
  let open Caqti_request.Infix in
  query |> ignore;
  let args = "foo", "bar" in
  let pt = Caqti_type.Std.(tup2 string string) in
  (* pack it to Dynparam.t *)
  let param = Dynparam.Pack (pt, args) in
  (* unpack again *)
  let (Dynparam.Pack (pt, _)) = param in
  let req = (pt ->? pt) @@ "SELECT * FROM customers" in
  print_endline (Format.asprintf "%a" Caqti_request.pp req);
  "SELECT * FROM customers"
;;
