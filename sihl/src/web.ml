type meth =
  | Get
  | Head
  | Options
  | Post
  | Put
  | Patch
  | Delete
  | Any

type handler = Rock.Request.t -> Rock.Response.t Lwt.t
type route = meth * string * handler

type router =
  { scope : string
  ; routes : route list
  ; middlewares : Rock.Middleware.t list
  }

let trailing_char s =
  let length = String.length s in
  try Some (String.sub s (length - 1) 1) with
  | _ -> None
;;

let tail s =
  try String.sub s 1 (String.length s - 1) with
  | _ -> ""
;;

let prefix prefix ((meth, path, handler) : route) =
  if String.equal path ""
  then meth, prefix, handler
  else (
    let path =
      match trailing_char prefix, Astring.String.head path with
      | Some "/", Some '/' -> Printf.sprintf "%s%s" prefix (tail path)
      | Some "/", Some _ -> Printf.sprintf "%s%s" prefix path
      | Some _, Some '/' -> Printf.sprintf "%s%s" prefix path
      | None, Some '/' -> Printf.sprintf "%s%s" prefix path
      | Some "/", None -> Printf.sprintf "%s%s" prefix path
      | _, _ -> Printf.sprintf "%s/%s" prefix path
    in
    let path = CCString.replace ~sub:"//" ~by:"/" path in
    meth, path, handler)
;;

let apply_middleware_stack
    (middleware_stack : Rock.Middleware.t list)
    ((meth, path, handler) : route)
  =
  (* The request goes through the middleware stack from top to bottom, so we
     have to reverse the middleware stack *)
  let middleware_stack = List.rev middleware_stack in
  let wrapped_handler =
    List.fold_left
      (fun handler middleware -> Rock.Middleware.apply middleware handler)
      handler
      middleware_stack
  in
  meth, path, wrapped_handler
;;

let get path ?(middlewares = []) handler =
  { scope = ""; routes = [ Get, path, handler ]; middlewares }
;;

let head path ?(middlewares = []) handler =
  { scope = ""; routes = [ Head, path, handler ]; middlewares }
;;

let options path ?(middlewares = []) handler =
  { scope = ""; routes = [ Options, path, handler ]; middlewares }
;;

let post path ?(middlewares = []) handler =
  { scope = ""; routes = [ Post, path, handler ]; middlewares }
;;

let put path ?(middlewares = []) handler =
  { scope = ""; routes = [ Put, path, handler ]; middlewares }
;;

let patch path ?(middlewares = []) handler =
  { scope = ""; routes = [ Patch, path, handler ]; middlewares }
;;

let delete path ?(middlewares = []) handler =
  { scope = ""; routes = [ Delete, path, handler ]; middlewares }
;;

let any path ?(middlewares = []) handler =
  { scope = ""; routes = [ Any, path, handler ]; middlewares }
;;

let routes_of_router ({ scope; routes; middlewares } : router) : route list =
  routes
  |> List.map (prefix scope)
  |> List.map (apply_middleware_stack middlewares)
;;

let choose ?(scope = "/") ?(middlewares = []) (routers : router list) : router =
  let scope =
    match CCString.chop_prefix ~pre:"/" scope with
    | Some prefix -> "/" ^ prefix
    | None -> "/" ^ scope
  in
  let routes = routers |> List.map routes_of_router |> List.concat in
  { scope; routes; middlewares }
;;

let externalize_path ?prefix path =
  let prefix =
    match prefix, Core_configuration.read_string "PREFIX_PATH" with
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
