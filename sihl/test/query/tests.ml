module Customer = Test_model.Customer

module All () = struct
  let () =
    let database = Config.database_url () |> Uri.to_string in
    Lwt_main.run
      (let%lwt () = Sihl.Test.tables_drop () in
       let%lwt () =
         Omigrate.create ~database
         |> Lwt_result.map_err Omigrate.Error.to_string
         |> Lwt.map CCResult.get_or_failwith
       in
       Lwt_io.with_temp_dir (fun path ->
           let%lwt () = Migration.generate path in
           Migration.up ~path ()))
  ;;

  let%test_unit "insert and query model" =
    let open Sihl.Test.Assert in
    let open Sihl.Query in
    Sihl.Test.with_db (fun conn ->
        let user : User.t =
          User.make
            ~role:Staff
            ~email:"hello@example.org"
            ~short_name:"walt"
            ~full_name:"walter"
            ~password:"123"
            ~created_at:(Ptime_clock.now ())
            ~updated_at:(Ptime_clock.now ())
        in
        let%lwt user_id = insert User.t user |> execute conn in
        let customer : Customer.t =
          Customer.make
            ~tier:Premium
            ~user_id
            ~street:"Some street 13"
            ~city:Zurich
            ~created_at:(Ptime_clock.now ())
            ~updated_at:(Ptime_clock.now ())
        in
        let%lwt pk = insert Customer.t customer |> execute conn in
        let%lwt pk_queried, customer_queried =
          all Customer.t
          |> where_string Customer.Fields.street eq "Some street 13"
          |> find conn
        in
        [%test_result: string] customer_queried.street ~expect:"Some street 13";
        [%test_result: int] pk ~expect:pk_queried;
        Lwt.return ())
  ;;
end
