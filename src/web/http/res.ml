open Http_core

(* TODO [jerben] remove all opium references *)
module OpiumResponse = struct
  (* We want to be able to derive show and eq from our own response type t *)
  type t = Opium_kernel.Response.t

  let equal _ _ = false
  let pp _ _ = ()
end

type body =
  | String of string
  | File_path of string
[@@deriving show, eq]

type t =
  { content_type : content_type
  ; redirect : string option
  ; body : body option
  ; headers : headers
  ; (* TODO [jerben] Remove all Opium references *)
    opium_res : OpiumResponse.t option
  ; cookies : (string * string) list
  ; status : int
  }
[@@deriving show, eq]

let file path content_type =
  { content_type
  ; redirect = None
  ; body = Some (File_path path)
  ; headers = []
  ; opium_res = None
  ; cookies = []
  ; status = 200
  }
;;

let html =
  { content_type = Html
  ; redirect = None
  ; body = None
  ; headers = []
  ; opium_res = None
  ; cookies = []
  ; status = 200
  }
;;

let json =
  { content_type = Json
  ; redirect = None
  ; body = None
  ; headers = []
  ; opium_res = None
  ; cookies = []
  ; status = 200
  }
;;

let redirect path =
  { content_type = Html
  ; redirect = Some path
  ; body = None
  ; headers = []
  ; opium_res = None
  ; cookies = []
  ; status = 302
  }
;;

let redirect_path res = res.redirect
let body res = res.body
let set_body str res = { res with body = Some (String str) }
let headers res = res.headers
let set_headers headers res = { res with headers }
let content_type res = res.content_type
let set_content_type content_type res = { res with content_type }

(* TODO [jerben] this is a hack and has to be removed *)
let opium_res res = res.opium_res

(* TODO [jerben] this is a hack and has to be removed *)
let set_opium_res opium_res res = { res with opium_res = Some opium_res }
let cookies res = res.cookies

(* TODO [jerben] Rename to add_cookie *)
let set_cookie ~key ~data res = { res with cookies = List.cons (key, data) res.cookies }
let status res = res.status
let set_status status res = { res with status }
