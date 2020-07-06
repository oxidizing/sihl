open Web_core

type t = {
  content_type : content_type;
  redirect : string option;
  body : string option;
  headers : headers;
}

let html = { content_type = Html; redirect = None; body = None; headers = [] }

let set_redirect path =
  { content_type = Html; redirect = Some path; body = None; headers = [] }

let set_body str req = { req with body = Some str }

let set_cookie ~key:_ ~data:_ _ = failwith "TODO set_cookie()"

let to_opium res =
  let headers = Cohttp.Header.of_list res.headers in
  let headers =
    Cohttp.Header.add headers "Content-Type"
      (show_content_type res.content_type)
  in
  let code = match res.redirect with Some _ -> 301 | None -> 200 in
  let headers =
    match res.redirect with
    | Some path -> Cohttp.Header.add headers "Location" path
    | None -> headers
  in
  let code = Cohttp.Code.status_of_code code in
  let body = `String (Option.value ~default:"" res.body) in
  Opium.Std.respond ~headers ~code body
