open Base

let m () app =
  let ( let* ) = Lwt.bind in
  let pool = Core.Db.connect () in
  let filter handler req =
    let response_ref : Opium.Std.Response.t option ref = ref None in
    let* _ =
      Caqti_lwt.Pool.use
        (fun connection ->
          let (module Connection : Caqti_lwt.CONNECTION) = connection in
          let env =
            Opium.Hmap.add Core.Db.key connection (Opium.Std.Request.env req)
          in
          let response = handler { req with env } in
          let* response = response in
          (* using a ref here is dangerous because we might escape the scope of
             the pool handler. we wait for the response, so all db handling is
             done here *)
          let _ = response_ref := Some response in
          Lwt.return @@ Ok ())
        pool
    in
    match !response_ref with
    | Some response -> Lwt.return response
    | None -> Core_err.raise_database "error happened"
  in
  let m =
    Opium.Std.Rock.Middleware.create ~name:"database connection" ~filter
  in
  Opium.Std.middleware m app
