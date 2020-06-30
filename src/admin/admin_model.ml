module Page = struct
  type t = { path : string; label : string }
  [@@deriving fields, yojson, show, eq, make]

  let path page = page.path

  let label page = page.label

  let create ~path ~label = { path; label }
end
