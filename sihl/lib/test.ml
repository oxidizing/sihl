let database (f : Caqti_lwt.connection -> 'a Lwt.t) : 'a =
  let database_uri = Config.database_url () in
  Lwt_main.run
    (Caqti_lwt.with_connection database_uri (fun conn ->
         f conn |> Lwt.map Result.ok))
  |> Result.get_ok
;;
