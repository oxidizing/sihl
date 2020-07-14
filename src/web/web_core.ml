type content_type = Html | Json [@@deriving show, eq]

let show_content_type = function
  | Html -> "text/html"
  | Json -> "application/json"

type header = string * string [@@deriving show, eq]

type headers = header list [@@deriving show, eq]
