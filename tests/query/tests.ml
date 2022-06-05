open Test_models

let () = Sihl.Config.configure (module Test_config.Base)

let%test "insert and query model" =
  let c1 : Customer.t =
    { id = -1
    ; user_id = 1
    ; tier = Premium
    ; street = "Somestreet"
    ; city = Zurich
    ; created_at = Ptime_clock.now ()
    ; updated_at = Ptime_clock.now ()
    }
  in
  Sihl.Test.database (fun conn ->
      let open Sihl.Query in
      let%lwt () = insert Customer.t c1 |> execute conn in
      let%lwt c2 =
        query Customer.t
        |> where Customer.Fields.street eq "Somestreet"
        |> find conn
      in
      Lwt.return @@ Customer.eq c1 c2)
;;
