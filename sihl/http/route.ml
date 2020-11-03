module Core = Sihl_core

type meth =
  | Get
  | Post
  | Put
  | Delete
  | Any

type handler = Opium_kernel.Request.t -> Opium_kernel.Response.t Lwt.t
type t = meth * string * handler

let get path handler = Get, path, handler
let post path handler = Post, path, handler
let put path handler = Put, path, handler
let delete path handler = Delete, path, handler
let any path handler = Any, path, handler

type router =
  { scope : string
  ; routes : t list
  ; middlewares : Opium_kernel.Rock.Middleware.t list
  }

let router ?(scope = "/") ?(middlewares = []) routes = { scope; routes; middlewares }

let trailing_char s =
  let length = String.length s in
  try Some (String.sub s (length - 1) 1) with
  | _ -> None
;;

let tail s =
  try String.sub s 1 (String.length s - 1) with
  | _ -> ""
;;

let prefix prefix (meth, path, handler) =
  let path =
    match trailing_char prefix, Astring.String.head path with
    | Some "/", Some '/' -> Printf.sprintf "%s%s" prefix (tail path)
    | _, _ -> Printf.sprintf "%s%s" prefix path
  in
  meth, path, handler
;;

let apply_middleware_stack middleware_stack (meth, path, handler) =
  (* The request goes through the middleware stack from top to bottom, so we have to
     reverse the middleware stack *)
  let middleware_stack = List.rev middleware_stack in
  let wrapped_handler =
    List.fold_left
      (fun handler middleware -> Opium_kernel.Rock.Middleware.apply middleware handler)
      handler
      middleware_stack
  in
  meth, path, wrapped_handler
;;

let router_to_routes { scope; routes; middlewares } =
  routes |> List.map (prefix scope) |> List.map (apply_middleware_stack middlewares)
;;

let externalize_path ?prefix path =
  let prefix =
    match prefix, Core.Configuration.read_string "PREFIX_PATH" with
    | Some prefix, _ -> prefix
    | _, Some prefix -> prefix
    | _ -> ""
  in
  path
  |> String.split_on_char '/'
  |> List.cons prefix
  |> String.concat "/"
  |> Stringext.replace_all ~pattern:"//" ~with_:"/"
;;
