type t =
  { id : string
  ; name : string
  ; content_text : string
  ; content_html : string
  ; created_at : Ptime.t
        [@to_yojson Sihl_core.Time.ptime_to_yojson]
        [@of_yojson Sihl_core.Time.ptime_of_yojson]
  }
[@@deriving yojson, show, eq, fields]

let set_name name template = { template with name }
let set_text content_text template = { template with content_text }
let set_html content_html template = { template with content_html }

let make ?text ?html name =
  { id = Uuidm.v `V4 |> Uuidm.to_string
  ; name
  ; content_text = text |> Option.value ~default:""
  ; content_html = html |> Option.value ~default:""
  ; created_at = Ptime_clock.now ()
  }
;;

let replace_element str k v =
  let regexp = Str.regexp @@ "{" ^ k ^ "}" in
  Str.global_replace regexp v str
;;

let render data template =
  let rec render_value data value =
    match data with
    | [] -> value
    | (k, v) :: data -> render_value data @@ replace_element value k v
  in
  let text = render_value data template.content_text in
  let html = render_value data template.content_html in
  text, html
;;

module Data = struct
  type t = (string * string) list [@@deriving show, eq]

  let empty = []
  let add ~key ~value data = List.cons (key, value) data
  let make data = data
end
