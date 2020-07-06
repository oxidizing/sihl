type content_type = Html [@@deriving show, eq]

let show_content_type = function Html -> "application/html"

type headers = (string * string) list
