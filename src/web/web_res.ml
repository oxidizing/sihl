open Base
open Web_core

module OpiumResponse = struct
  (* We want to be able to derive show and eq from our own response type t *)
  type t = Opium_kernel.Response.t

  let equal _ _ = false

  let pp _ _ = ()
end

type t = {
  content_type : content_type;
  redirect : string option;
  body : string option;
  headers : headers;
  opium_res : OpiumResponse.t option;
  cookies : (string * string) list;
  status : int;
}
[@@deriving show, eq]

let html =
  {
    content_type = Html;
    redirect = None;
    body = None;
    headers = [];
    opium_res = None;
    cookies = [];
    status = 200;
  }

let json =
  {
    content_type = Json;
    redirect = None;
    body = None;
    headers = [];
    opium_res = None;
    cookies = [];
    status = 200;
  }

let redirect path =
  {
    content_type = Html;
    redirect = Some path;
    body = None;
    headers = [];
    opium_res = None;
    cookies = [];
    status = 302;
  }

let set_body str res = { res with body = Some str }

let set_content_type content_type res = { res with content_type }

let set_opium_res opium_res res = { res with opium_res = Some opium_res }

let set_cookie ~key ~data res =
  { res with cookies = List.cons (key, data) res.cookies }

let set_status status res = { res with status }

let to_opium res =
  match res.opium_res with
  | Some res -> res
  | None ->
      let headers = Cohttp.Header.of_list res.headers in
      let headers =
        Cohttp.Header.add headers "Content-Type"
          (show_content_type res.content_type)
      in
      let code = res.status |> Cohttp.Code.status_of_code in
      let headers =
        match res.redirect with
        | Some path -> Cohttp.Header.add headers "Location" path
        | None -> headers
      in
      let body = `String (Option.value ~default:"" res.body) in
      let cookie_headers =
        res.cookies
        |> List.map ~f:(fun cookie ->
               Cohttp.Cookie.Set_cookie_hdr.make ~secure:false ~path:"/" cookie)
        |> List.map ~f:Cohttp.Cookie.Set_cookie_hdr.serialize
      in
      let headers =
        List.fold_left cookie_headers ~init:headers ~f:(fun headers (k, v) ->
            Cohttp.Header.add headers k v)
      in
      Opium.Std.respond ~headers ~code body
