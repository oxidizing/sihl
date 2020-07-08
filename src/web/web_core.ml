type content_type = Html [@@deriving show, eq]

let show_content_type = function Html -> "text/html"

type header = string * string [@@deriving show, eq]

type headers = header list [@@deriving show, eq]
