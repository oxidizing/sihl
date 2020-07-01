open Base

let ( let* ) = Lwt_result.bind

type t = Opium.Std.Request.t

let ctx_of _ = failwith "TODO ctx_of"

let find_in_query key query =
  query
  |> List.find ~f:(fun (k, _) -> String.equal k key)
  |> Option.map ~f:(fun (_, r) -> r)
  |> Option.bind ~f:List.hd

let urlencoded ?body req key =
  (* we need to be able to pass in the body
     because Opium.Std.Request.body drains
     the body stream from the request *)
  let* body =
    match body with
    | Some body -> Lwt.return @@ Ok body
    | None ->
        req |> Opium.Std.Request.body |> Opium.Std.Body.to_string
        |> Lwt.map Result.return
  in
  match body |> Uri.pct_decode |> Uri.query_of_encoded |> find_in_query key with
  | None -> Lwt.return @@ Error (Printf.sprintf "Please provide a %s." key)
  | Some value -> Lwt.return @@ Ok value

let urlencoded2 req key1 key2 =
  let* body =
    req |> Opium.Std.Request.body |> Opium.Std.Body.to_string
    |> Lwt.map Result.return
  in
  let* value1 = urlencoded ~body req key1 in
  let* value2 = urlencoded ~body req key2 in
  Lwt.return @@ Ok (value1, value2)

let urlencoded3 req key1 key2 key3 =
  let* body =
    req |> Opium.Std.Request.body |> Opium.Std.Body.to_string
    |> Lwt.map Result.return
  in
  let* value1 = urlencoded ~body req key1 in
  let* value2 = urlencoded ~body req key2 in
  let* value3 = urlencoded ~body req key3 in
  Lwt.return @@ Ok (value1, value2, value3)
