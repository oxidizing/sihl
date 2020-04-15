open Core
open Opium.Std

let require_auth req =
  match req |> Cohttp.Header.get_authorization with
  | None -> failwith "No authorization header found"
  | Some token -> token

let query req key =
  let query = req |> Request.uri |> Uri.query in
  let value =
    query
    |> List.find ~f:(fun (k, _) -> String.equal k key)
    |> Option.map ~f:Tuple2.get2 |> Option.bind ~f:List.hd
  in
  match value with
  | None -> failwith @@ "required query not found key= " ^ key
  | Some value -> value

let query2 req key1 key2 = (query req key1, query req key2)

let query3 req key1 key2 key3 = (query req key1, query req key2, query req key3)

let param = Opium.Std.param

let param2 req key1 key2 = (param req key1, param req key2)

let param3 req key1 key2 key3 = (param req key1, param req key2, param req key3)

let failwith_opt msg opt =
  match opt with None -> failwith msg | Some value -> value

let failwith_result opt =
  match opt with Error msg -> failwith msg | Ok value -> value
