let router ?(scope = "/") ?(middlewares = []) routes =
  Service.{ scope; routes; middlewares }
;;

let get path handler = Service.(Get, path, handler)
let post path handler = Service.(Post, path, handler)
let put path handler = Service.(Put, path, handler)
let delete path handler = Service.(Delete, path, handler)
let any path handler = Service.(Any, path, handler)

let externalize ?prefix path =
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

module Response = Response
module Request = Request
module Service = Service
module Cookie = Cookie
