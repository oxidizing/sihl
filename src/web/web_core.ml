type content_type = Html [@@deriving show, eq]

let show_content_type = function Html -> "application/html"

type header = string * string

type headers = header list
