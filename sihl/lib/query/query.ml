include Query_pure
module Sql = Query_sql

let asc field = Asc field
let desc field = Desc field

let show
    (t :
      [< `Select of 'a Model.t * select
      | `Insert of 'a Model.t * 'a
      | `Update of 'a Model.t * 'a
      ])
    : string
  =
  match t with
  | `Select (model, select) -> Sql.select_stmt model select
  | `Insert (model, _) -> Sql.insert_stmt model
  | `Update (model, _) -> Sql.update_stmt model
;;

let insert (type a) (model : a Model.t) (v : a) : [ `Insert of a Model.t * a ] =
  `Insert (model, v)
;;

let execute
    (db : Caqti_lwt.connection)
    (q : [< `Insert of 'a Model.t * 'a | `Update of 'a Model.t * 'a ])
    : int Lwt.t
  =
  match q with
  | `Insert (model, v) -> Sql.insert db model v
  | `Update (model, v) -> Sql.update db model v
;;

let all (type a) (model : a Model.t) : a read =
  `Select (model, { filter = None; order_by = []; limit = None; offset = None })
;;

let eq : op = Eq
let gt : op = Gt
let lt : op = Lt
let like : op = Like

let field_int (name : string) : ('perm, 'a, int) Model.record_field =
  Fieldslib.Field.Field
    { force_variance = (fun _ -> ())
    ; name
    ; setter = None
    ; getter = (fun _ -> 0)
    ; fset = (fun a _ -> a)
    }
;;

let where_int
    ?(join : string list = [])
    (field : ('perm, 'a, int) Model.record_field)
    (op : op)
    (value : int)
    (query : 'b read)
    : 'b read
  =
  let (`Select (model, select)) = query in
  let added_filter =
    Filter
      { op; join; field_name = Fieldslib.Field.name field; value = `Int value }
  in
  let updated_filter =
    match select.filter with
    | Some (And []) | Some (Or []) -> Some (And [ added_filter ])
    | Some (And filters) -> Some (And (List.cons added_filter filters))
    | Some (Or filters) -> Some (And [ Or filters; added_filter ])
    | Some (Filter filter) -> Some (And [ Filter filter; added_filter ])
    | None -> Some added_filter
  in
  `Select (model, { select with filter = updated_filter })
;;

let where_string
    ?(join : string list = [])
    (field : ('perm, 'a, string) Model.record_field)
    (op : op)
    (value : string)
    (query : 'b read)
    : 'b read
  =
  let (`Select (model, select)) = query in
  let added_filter =
    Filter
      { op
      ; join
      ; field_name = Fieldslib.Field.name field
      ; value = `String value
      }
  in
  let updated_filter =
    match select.filter with
    | Some (And []) | Some (Or []) -> Some (And [ added_filter ])
    | Some (And filters) -> Some (And (List.cons added_filter filters))
    | Some (Or filters) -> Some (And [ Or filters; added_filter ])
    | Some (Filter filter) -> Some (And [ Filter filter; added_filter ])
    | None -> Some added_filter
  in
  `Select (model, { select with filter = updated_filter })
;;

let or_ (type a) (wheres : (a read -> a read) list) (query : a read) : a read =
  let (`Select (model, select)) = query in
  let empty =
    `Select
      (model, { filter = None; order_by = []; limit = None; offset = None })
  in
  let (`Select (_, { filter; _ })) =
    List.fold_left (fun a b -> b a) empty wheres
  in
  let updated_filter =
    match select.filter, filter with
    | Some before_filter, Some new_filter -> Or [ before_filter; new_filter ]
    | Some before_filter, None -> Or [ before_filter ]
    | None, Some new_filter -> Or [ new_filter ]
    | None, None -> Or []
  in
  `Select (model, { select with filter = Some updated_filter })
;;

let order_by (type a) (order_by : order_by list) (query : a read) : a read =
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

let find
    (type a)
    (conn : Caqti_lwt.connection)
    (`Select (model, select) : a read)
    : (int * a) Lwt.t
  =
  let _, record = model in
  let%lwt v = Sql.find_opt conn model select in
  match v with
  | Some v -> Lwt.return v
  | None -> failwith @@ Format.sprintf "no %s found" record.name
;;

let find_all (type a) (conn : Caqti_lwt.connection) (query : a read)
    : a list Lwt.t
  =
  conn |> ignore;
  query |> ignore;
  failwith "find_all()"
;;
