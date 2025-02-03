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
      | None, None -> Printf.sprintf "%s%s" prefix path
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

let choose ?(scope = "") ?(middlewares = []) (routers : router list) : router =
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

(* This is a generic style that is used in various middlewares. It is based on
   the style of
   https://github.com/rgrinberg/opium/blob/master/opium/src/middlewares/middleware_debugger.ml *)
let style =
  {|/*! normalize.css v8.0.1 | MIT License | github.com/necolas/normalize.css */html{line-height:1.15;-webkit-text-size-adjust:100%}body{margin:0}code,pre{font-family:monospace,monospace;font-size:1em}[type=button],[type=reset],[type=submit]{-webkit-appearance:button}[type=button]::-moz-focus-inner,[type=reset]::-moz-focus-inner,[type=submit]::-moz-focus-inner{border-style:none;padding:0}[type=button]:-moz-focusring,[type=reset]:-moz-focusring,[type=submit]:-moz-focusring{outline:1px dotted ButtonText}[type=checkbox],[type=radio]{box-sizing:border-box;padding:0}[type=number]::-webkit-inner-spin-button,[type=number]::-webkit-outer-spin-button{height:auto}[type=search]{-webkit-appearance:textfield;outline-offset:-2px}[type=search]::-webkit-search-decoration{-webkit-appearance:none}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}[hidden]{display:none}h2,h3,pre{margin:0}html{font-family:system-ui,-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica Neue,Arial,Noto Sans,sans-serif,Apple Color Emoji,Segoe UI Emoji,Segoe UI Symbol,Noto Color Emoji;line-height:1.5}*,:after,:before{box-sizing:border-box;border:0 solid #e2e8f0}[role=button]{cursor:pointer}h2,h3{font-size:inherit;font-weight:inherit}code,pre{font-family:Menlo,Monaco,Consolas,Liberation Mono,Courier New,monospace}.bg-white{--bg-opacity:1;background-color:#fff;background-color:rgba(255,255,255,var(--bg-opacity))}.bg-gray-500{--bg-opacity:1;background-color:#a0aec0;background-color:rgba(160,174,192,var(--bg-opacity))}.bg-gray-800{--bg-opacity:1;background-color:#2d3748;background-color:rgba(45,55,72,var(--bg-opacity))}.border-gray-200{--border-opacity:1;border-color:#edf2f7;border-color:rgba(237,242,247,var(--border-opacity))}.border-t{border-top-width:1px}.border-b{border-bottom-width:1px}.block{display:block}.inline-block{display:inline-block}.flex{display:flex}.items-center{align-items:center}.justify-between{justify-content:space-between}.font-semibold{font-weight:600}.text-sm{font-size:.875rem}.text-base{font-size:1rem}.text-2xl{font-size:1.5rem}.leading-8{line-height:2rem}.leading-snug{line-height:1.375}.leading-normal{line-height:1.5}.m-0{margin:0}.mx-auto{margin-left:auto;margin-right:auto}.mt-0{margin-top:0}.mb-4{margin-bottom:1rem}.mt-6{margin-top:1.5rem}.overflow-auto{overflow:auto}.overflow-hidden{overflow:hidden}.scrolling-touch{-webkit-overflow-scrolling:touch}.p-0{padding:0}.p-4{padding:1rem}.py-2{padding-top:.5rem;padding-bottom:.5rem}.py-4{padding-top:1rem;padding-bottom:1rem}.px-4{padding-left:1rem;padding-right:1rem}.relative{position:relative}.text-white{--text-opacity:1;color:#fff;color:rgba(255,255,255,var(--text-opacity))}.text-gray-600{--text-opacity:1;color:#718096;color:rgba(113,128,150,var(--text-opacity))}.text-gray-900{--text-opacity:1;color:#1a202c;color:rgba(26,32,44,var(--text-opacity))}.antialiased{-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale}.subpixel-antialiased{-webkit-font-smoothing:auto;-moz-osx-font-smoothing:auto}.truncate{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}@media (min-width:640px){.sm\:rounded-lg{border-radius:.5rem}.sm\:border{border-width:1px}.sm\:items-baseline{align-items:baseline}.sm\:text-3xl{font-size:1.875rem}.sm\:leading-9{line-height:2.25rem}.sm\:py-4{padding-top:1rem;padding-bottom:1rem}.sm\:px-6{padding-left:1.5rem;padding-right:1.5rem}.sm\:py-12{padding-top:3rem;padding-bottom:3rem}}@media (min-width:768px){.md\:text-lg{font-size:1.125rem}}@media (min-width:1024px){.lg\:px-8{padding-left:2rem;padding-right:2rem}}|}
;;
