open Test_model

module Db () = struct
  (* TODO uncomment once we implemented the functions without Obj.magic () *)
  (* let%test "insert and query model" = *)
  (*   let customer : Customer.t = *)
  (*     Customer.make *)
  (*       ~user_id:1 *)
  (*       ~tier:Premium *)
  (*       ~street:"Some street 13" *)
  (*       ~city:Zurich *)
  (*       ~created_at:(Ptime_clock.now ()) *)
  (*       ~updated_at:(Ptime_clock.now ()) *)
  (*       () *)
  (*   in *)
  (*   Sihl.Test.database (fun conn -> *)
  (*       let open Sihl.Query in *)
  (*       let%lwt () = insert Customer.t customer |> execute conn in *)
  (*       let%lwt customer_queried = *)
  (*         query Customer.t *)
  (*         |> where Customer.Fields.street eq "Some street 13" *)
  (*         |> find conn *)
  (*       in *)
  (*       Lwt.return *)
  (*         (String.equal customer.street customer_queried.street *)
  (*         && Option.is_some customer_queried.id)) *)
  (* ;; *)
end

let%test_unit "query" =
  let open Sihl.Query in
  let _ =
    all Customer.t
    |> and_where Customer.Fields.street eq "some street"
    |> or_
         [ and_where
             ~join:[ table "user" ]
             Sihl.User.Fields.email
             like
             "%@example.org"
         ; and_where ~join:[ "user" ] Sihl.User.Fields.email like "%@gmail.com"
         ]
    |> order_by [ asc "created_at"; desc "updated_at" ]
    |> limit 50
    |> offset 10
  in
  ()
;;
