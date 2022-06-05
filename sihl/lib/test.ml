let database (f : Caqti_lwt.connection -> 'a Lwt.t) : 'a =
  let database_uri = Config.database_url () in
  match
    Lwt_main.run
      (Caqti_lwt.with_connection database_uri (fun conn ->
           f conn |> Lwt.map Result.ok))
    |> Result.map_error Caqti_error.show
  with
  | Error msg -> failwith msg
  | Ok v -> v
;;
