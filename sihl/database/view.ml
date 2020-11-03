module Repository = Sihl_repository

module PartialCollection = struct
  type controls =
    { first : Ql.Page.t option
    ; previous : Ql.Page.t option
    ; next : Ql.Page.t option
    ; last : Ql.Page.t option
    }
  [@@deriving show, eq, fields, yojson]

  type 'a t =
    { member : 'a list
    ; total_items : int
    ; controls : controls
    }
  [@@deriving show, eq, fields, yojson]

  let controls_of_pagination page total_items =
    let limit = Ql.Page.get_limit page in
    let offset = Ql.Page.get_offset page in
    let limit = Option.value ~default:25 limit in
    let offset = Option.value ~default:0 offset in
    let first = if offset <= 0 then None else Some (Ql.Page.set_offset 0 page) in
    let previous =
      if offset - limit >= 0
      then Some (Ql.Page.set_offset (offset - limit) page)
      else None
    in
    let next =
      if offset + limit < total_items
      then Some (Ql.Page.set_offset (offset + limit) page)
      else None
    in
    let last =
      if offset < total_items - limit
      then Some (Ql.Page.set_offset (total_items - 1) page)
      else None
    in
    { first; previous; next; last }
  ;;

  let create ~page ~meta items =
    let total_items = Repository.Meta.total meta in
    let controls = controls_of_pagination page total_items in
    { member = items; total_items; controls }
  ;;
end
