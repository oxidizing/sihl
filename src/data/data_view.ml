open Base

module PartialCollection = struct
  type page = { offset : int; limit : int }
  [@@deriving show, eq, yojson, fields]

  type view = {
    first : page option;
    previous : page option;
    next : page option;
    last : page option;
  }
  [@@deriving show, eq, yojson, fields]

  type 'a t = { id : string; member : 'a list; total_items : int; view : view }
  [@@deriving show, eq, yojson, fields]

  let view_of_pagination limit offset total_items =
    let limit = Option.value ~default:25 limit in
    let offset = Option.value ~default:0 offset in
    let first = if offset <= 0 then None else Some { offset = 0; limit } in
    let previous =
      if offset - limit >= 0 then Some { offset = offset - limit; limit }
      else None
    in
    let next =
      if offset + limit < total_items then
        Some { offset = offset + limit; limit }
      else None
    in
    let last =
      if offset < total_items - limit then
        Some { offset = total_items - 1; limit }
      else None
    in
    { first; previous; next; last }

  let create id ~query ~meta items =
    let offset = Data_ql.offset query in
    let limit = Data_ql.offset query in
    let total_count = Data_repo.Meta.total meta in
    let view = view_of_pagination limit offset total_count in
    { id; member = items; total_items = total_count; view }
end
