(* open Test_models *)

module Run () = struct
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
