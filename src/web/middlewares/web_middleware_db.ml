open Base

let ( let* ) = Lwt.bind

let m () =
  let pool = Data.Db.create_pool () |> Result.ok_or_failwith in
  let filter handler req =
    let response_ref : Opium.Std.Response.t option ref = ref None in
    let* _ =
      Caqti_lwt.Pool.use
        (fun connection ->
          let (module Connection : Caqti_lwt.CONNECTION) = connection in
          let env =
            Opium.Hmap.add Data.Db.middleware_key_connection connection
              (Opium.Std.Request.env req)
          in
          let response = handler { req with env } in
          let* response = response in
          (* Using a ref here is dangerous because we might escape the scope of
             the pool handler. we wait for the response, so all db handling is
             done here *)
          let _ = response_ref := Some response in
          Lwt.return @@ Ok ())
        pool
    in
    match !response_ref with
    | Some response -> Lwt.return response
    | None -> failwith "error happened in db middleware"
  in
  Opium.Std.Rock.Middleware.create ~name:"database connection" ~filter