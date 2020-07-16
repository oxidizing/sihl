open Base

module PartialCollection = struct
  type view = {
    first : Data_ql.t option;
    previous : Data_ql.t option;
    next : Data_ql.t option;
    last : Data_ql.t option;
  }
  [@@deriving show, eq, fields, yojson]

  type 'a t = { id : string; member : 'a list; total_items : int; view : view }
  [@@deriving show, eq, fields, yojson]

  let view_of_pagination query total_items =
    let limit = Data_ql.limit query in
    let offset = Data_ql.offset query in
    let limit = Option.value ~default:25 limit in
    let offset = Option.value ~default:0 offset in
    let first =
      if offset <= 0 then None else Some (Data_ql.set_offset 0 query)
    in
    let previous =
      if offset - limit >= 0 then
        Some (Data_ql.set_offset (offset - limit) query)
      else None
    in
    let next =
      if offset + limit < total_items then
        Some (Data_ql.set_offset (offset + limit) query)
      else None
    in
    let last =
      if offset < total_items - limit then
        Some (Data_ql.set_offset (total_items - 1) query)
      else None
    in
    { first; previous; next; last }

  let create id ~query ~meta items =
    let total_items = Data_repo.Meta.total meta in
    let view = view_of_pagination query total_items in
    { id; member = items; total_items; view }
end
