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

module Assert = struct
  let sexp_of_string = Sexplib0.Sexp_conv.sexp_of_string
  let compare_string = String.compare
  let compare_int = Int.compare
  let compare_bool = Bool.compare
end
