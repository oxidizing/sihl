type content_type = Html | Json | Pdf [@@deriving show, eq]

let show_content_type = function
  | Html -> "text/html"
  | Json -> "application/json"
  | Pdf -> "application/pdf"

type header = string * string [@@deriving show, eq]

type headers = header list [@@deriving show, eq]
