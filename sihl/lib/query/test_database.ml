module Customer = struct
  type city =
    | Zurich
    | Bern
    | Basel
  [@@deriving yojson]

  type tier =
    | Premium
    | Top
    | Business
    | Standard
  [@@deriving yojson]

  type t =
    { user_id : int
    ; tier : tier
    ; street : string
    ; city : city
    ; created_at : Model.Ptime.t
    ; updated_at : Model.Ptime.t
    }
  [@@deriving fields, yojson, make]

  let schema =
    Model.
      [ foreign_key Cascade "users" Fields.user_id
      ; enum tier_of_yojson tier_to_yojson Fields.tier
      ; string ~max_length:30 Fields.street
      ; enum city_of_yojson city_to_yojson Fields.city
      ; timestamp ~default:Now Fields.created_at
      ; timestamp ~default:Now ~update:true Fields.updated_at
      ]
  ;;

  let validate (t : t) =
    match t.tier, t.city with
    | Standard, Zurich ->
      [ "A customer from Zurich can not have tier Standard" ]
    | Business, Basel -> [ "A customer from Basel can not have tier Business" ]
    | Premium, Bern -> [ "A customer from Bern can not have tier Premium" ]
    | _ -> []
  ;;

  let t =
    Model.create ~validate to_yojson of_yojson "customers" Fields.names schema
  ;;

  let pp = Model.pp t [@@ocaml.toplevel_printer]
  let eq = Model.eq t
end

module Order = struct
  type t =
    { customer_id : int
    ; description : string
    ; created_at : Model.Ptime.t
    ; updated_at : Model.Ptime.t
    }
  [@@deriving fields, yojson]

  let schema =
    Model.
      [ foreign_key Cascade "customers" Fields.customer_id
      ; string ~max_length:255 Fields.description
      ; timestamp ~default:Now Fields.created_at
      ; timestamp ~default:Now ~update:true Fields.updated_at
      ]
  ;;

  let t = Model.create to_yojson of_yojson "orders" Fields.names schema
end

module Cases () = struct
  let () =
    let database = Config.database_url () |> Uri.to_string in
    Lwt_main.run
      (let%lwt () = Test.tables_drop () in
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
    let open Test.Assert in
    let open Query in
    Test.with_db (fun conn ->
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
