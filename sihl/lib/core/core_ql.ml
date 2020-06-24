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
  let limit limit = ("LIMIT ?", limit)

  let offset offset = ("OFFSET ?", offset)

  let sort sort =
    let values = ref [] in
    let sorts =
      sort
      |> List.map ~f:(function
           | Sort.Asc value ->
               values := List.concat [ !values; [ value ] ];
               "? ASC"
           | Sort.Desc value ->
               values := List.concat [ !values; [ value ] ];
               "? DESC")
      |> String.concat ~sep:", "
    in
    (Printf.sprintf "ORDER BY %s" sorts, !values)

  let filter_criterion_to_string criterion =
    let op_string =
      Filter.(match criterion.op with Eq -> "=" | Like -> "LIKE")
    in
    Printf.sprintf "%s %s ?" criterion.key op_string

  let is_whitelisted whitelist filter =
    match filter with
    | Filter.C criterion ->
        whitelist
        |> List.find ~f:(String.equal Filter.(criterion.key))
        |> Option.is_some
    | _ -> true

  let filter whitelist filter =
    let values = ref [] in
    let rec to_string filter =
      Filter.(
        match filter with
        | C criterion ->
            values := List.concat [ !values; [ criterion.value ] ];
            filter_criterion_to_string criterion
        | And [] -> ""
        | Or [] -> ""
        | And filters ->
            let whitelisted_filters =
              filters |> List.filter ~f:(is_whitelisted whitelist)
            in
            let criterions_string =
              whitelisted_filters |> List.map ~f:to_string
              |> String.concat ~sep:" AND "
            in
            if List.length whitelisted_filters > 1 then
              Printf.sprintf "(%s)" criterions_string
            else Printf.sprintf "%s" criterions_string
        | Or filters ->
            let whitelisted_filters =
              filters |> List.filter ~f:(is_whitelisted whitelist)
            in
            let criterions_string =
              whitelisted_filters |> List.map ~f:to_string
              |> String.concat ~sep:" OR "
            in
            if List.length whitelisted_filters > 1 then
              Printf.sprintf "(%s)" criterions_string
            else Printf.sprintf "%s" criterions_string)
    in
    let result = to_string filter in
    let result =
      if String.is_empty result then "" else Printf.sprintf "WHERE %s" result
    in
    (result, !values)

  let to_fragments filter_whitelist query =
    let filter_fragment =
      Option.map ~f:(filter filter_whitelist) query.filter
    in
    let sort_fragment = Option.map ~f:sort query.sort in
    let limit_fragment = Option.map ~f:limit query.limit in
    let offset_fragment = Option.map ~f:offset query.offset in
    (filter_fragment, sort_fragment, limit_fragment, offset_fragment)

  let to_string filter_whitelist query =
    let filter_fragment, sort_fragment, limit_fragment, offset_fragment =
      to_fragments filter_whitelist query
    in
    let limit_fragment =
      limit_fragment
      |> Option.map ~f:(fun (qs, value) -> (qs, [ Int.to_string value ]))
    in
    let offset_fragment =
      offset_fragment
      |> Option.map ~f:(fun (qs, value) -> (qs, [ Int.to_string value ]))
    in
    let qs =
      List.filter ~f:Option.is_some
        [ filter_fragment; sort_fragment; limit_fragment; offset_fragment ]
      |> List.map ~f:(Option.map ~f:(fun (qs, _) -> qs))
      |> List.map ~f:(Option.value ~default:"")
      |> String.concat ~sep:" "
    in
    let values =
      List.filter ~f:Option.is_some
        [ filter_fragment; sort_fragment; limit_fragment; offset_fragment ]
      |> List.map ~f:(Option.map ~f:(fun (_, values) -> values))
      |> List.map ~f:(Option.value ~default:[])
      |> List.concat
    in
    (qs, values)
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

let to_sql_fragments = Sql.to_fragments

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
