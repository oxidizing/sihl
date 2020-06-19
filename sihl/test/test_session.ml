open Base

let session_not_expired _ () =
  let expire_date =
    Option.value_exn
      ( 60 * 60 * 24
      |> Ptime.Span.of_int_s
      |> Ptime.add_span (Ptime_clock.now ()) )
  in
  let session = Sihl.Session.create ~expire_date (Ptime_clock.now ()) in
  Lwt.return
  @@ Alcotest.(
       check bool "is not expired" false
         (Sihl.Session.is_expired (Ptime_clock.now ()) session))
