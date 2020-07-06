open Base
open Web_core

type t = {
  content_type : content_type;
  redirect : string option;
  body : string option;
  headers : headers;
  opium_res : Opium_kernel.Response.t option;
  cookies : (string * string) list;
}

let html =
  {
    content_type = Html;
    redirect = None;
    body = None;
    headers = [];
    opium_res = None;
    cookies = [];
  }

let set_redirect path =
  {
    content_type = Html;
    redirect = Some path;
    body = None;
    headers = [];
    opium_res = None;
    cookies = [];
  }

let set_body str res = { res with body = Some str }

let set_opium_res opium_res res = { res with opium_res = Some opium_res }

let set_cookie ~key ~data res =
  { res with cookies = List.cons (key, data) res.cookies }

let to_opium res =
  match res.opium_res with
  | Some res -> res
  | None ->
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
      let opium_res = Opium.Std.respond ~headers ~code body in
      List.fold_left res.cookies ~init:opium_res
        ~f:(fun opium_res (key, data) ->
          Opium.Std.Cookie.set opium_res ~key ~data)
