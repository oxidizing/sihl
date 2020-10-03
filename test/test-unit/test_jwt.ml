open Base

let is_not_expired _ () =
  let secret = "foo" in
  let now = Ptime_clock.now () in
  let a_day = Sihl.Utils.Time.OneDay in
  let encoded_jwt =
    Sihl.Utils.Jwt.(empty |> set_expires_in ~now a_day |> encode HS256 ~secret)
    |> Result.ok_or_failwith
  in
  let decoded_jwt = Sihl.Utils.Jwt.decode ~secret encoded_jwt |> Result.ok_or_failwith in
  let actual = Sihl.Utils.Jwt.is_expired ~now decoded_jwt in
  let expected = false in
  Alcotest.(check bool "is not expired" expected actual);
  Lwt.return ()
;;

let is_expired _ () =
  let secret = "foo" in
  let past_s = Ptime_clock.now () |> Ptime.to_float_s in
  let past = Option.value_exn (Ptime.of_float_s (past_s -. 200000.)) in
  let a_day = Sihl.Utils.Time.OneDay in
  let encoded_jwt =
    Sihl.Utils.Jwt.(empty |> set_expires_in ~now:past a_day |> encode HS256 ~secret)
    |> Result.ok_or_failwith
  in
  let decoded_jwt = Sihl.Utils.Jwt.decode ~secret encoded_jwt |> Result.ok_or_failwith in
  let actual = Sihl.Utils.Jwt.is_expired ~now:(Ptime_clock.now ()) decoded_jwt in
  let expected = true in
  Alcotest.(check bool "is expired" expected actual);
  Lwt.return ()
;;
