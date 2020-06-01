type t = { path : string; label : string }

let path page = page.path

let label page = page.label

let create ~path ~label = { path; label }
