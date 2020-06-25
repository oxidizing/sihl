module Req = Http_req
module Res = Http_res
module Cookie = Http_cookie

let handle handler req = req |> handler |> Lwt.map Res.to_cohttp

let get path handler = Opium.Std.get path (handle handler)

let post path handler = Opium.Std.post path (handle handler)

let delete path handler = Opium.Std.delete path (handle handler)

let put path handler = Opium.Std.put path (handle handler)

let all path handler = Opium.Std.all path (handle handler)

let ctx _ = failwith "Implement Http.ctx"
