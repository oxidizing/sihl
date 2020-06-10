open Base

module Filter = struct
  type op = Eq | Like [@@deriving show, eq, sexp]

  type criterion = { key : string; value : string; op : op }
  [@@deriving show, eq, sexp]

  type t = And of t list | Or of t list | C of criterion
  [@@deriving show, eq, sexp]
end

module Sort = struct
  type criterion = Asc of string | Desc of string [@@deriving show, eq, sexp]

  type t = criterion list [@@deriving show, eq, sexp]
end

type t = {
  filter : Filter.t option; [@sexp.option]
  sort : Sort.t option; [@sexp.option]
  limit : int option; [@sexp.option]
  offset : int option; [@sexp.option]
}
[@@deriving show, eq, sexp]

module Sql = struct
  let limit limit = Printf.sprintf "LIMIT %d" limit

  let offset offset = Printf.sprintf "OFFSET %d" offset

  let sort sort =
    let sorts =
      sort
      |> List.map ~f:(function
           | Sort.Asc value -> Printf.sprintf "%s ASC" value
           | Sort.Desc value -> Printf.sprintf "%s DESC" value)
      |> String.concat ~sep:", "
    in
    Printf.sprintf "ORDER BY %s" sorts

  let filter_criterion_to_string criterion =
    let op_string =
      Filter.(match criterion.op with Eq -> "=" | Like -> "LIKE")
    in
    Printf.sprintf "%s %s %s" criterion.key op_string criterion.value

  let filter filter =
    let rec to_string filter =
      Filter.(
        match filter with
        | C criterion -> filter_criterion_to_string criterion
        | And [] -> ""
        | Or [] -> ""
        | And criterions ->
            let criterions_string =
              criterions |> List.map ~f:to_string |> String.concat ~sep:" AND "
            in
            Printf.sprintf "(%s)" criterions_string
        | Or criterions ->
            let criterions_string =
              criterions |> List.map ~f:to_string |> String.concat ~sep:" OR "
            in
            Printf.sprintf "(%s)" criterions_string)
    in
    let result = to_string filter in
    if String.is_empty result then "" else Printf.sprintf "WHERE %s" result

  let to_string query =
    let filter_fragment = Option.map ~f:filter query.filter in
    let sort_fragment = Option.map ~f:sort query.sort in
    let limit_fragment = Option.map ~f:limit query.limit in
    let offset_fragment = Option.map ~f:offset query.offset in
    List.filter ~f:Option.is_some
      [ filter_fragment; sort_fragment; limit_fragment; offset_fragment ]
    |> List.map ~f:(Option.value ~default:"")
    |> String.concat ~sep:" "
end

let of_string str =
  if String.equal str "" then
    Ok { filter = None; sort = None; limit = None; offset = None }
  else
    let sexp = Sexplib.Sexp.of_string str in
    Ok (t_of_sexp sexp)

let to_string query =
  let sexp = query |> sexp_of_t in
  Sexplib.Sexp.to_string sexp

let to_sql = Sql.to_string

let empty = { filter = None; sort = None; limit = None; offset = None }

let set_filter filter query = { query with filter = Some filter }

let set_filter_and criterion query =
  let open Filter in
  let new_filter =
    match query.filter with
    | Some filter -> And (List.append [ filter ] [ C criterion ])
    | None -> C criterion
  in
  { query with filter = Some new_filter }

let set_sort sort query = { query with sort = Some sort }

let set_limit limit query = { query with limit = Some limit }

let set_offset offset query = { query with offset = Some offset }

let limit query = query.limit

let offset query = query.offset
