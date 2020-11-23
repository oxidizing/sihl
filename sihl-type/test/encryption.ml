let xor_empty _ () =
  Alcotest.(
    check
      (option (list char))
      "XORs both empty"
      (Some [])
      (Sihl_core.Utils.Encryption.xor [] []));
  Lwt.return ()
;;

let xor_valid _ () =
  let io =
    [ ("a", "8"), "Y"; ("hello", "12345"), "YW_XZ"; ("{}|[]", " !\"#%"), "[\\^xx" ]
  in
  List.iter
    (fun ((v1, v2), r) ->
      Alcotest.(
        check
          (option (list char))
          "XORs ASCII"
          (Some (r |> String.to_seq |> List.of_seq))
          (Sihl_core.Utils.Encryption.xor
             (v1 |> String.to_seq |> List.of_seq)
             (v2 |> String.to_seq |> List.of_seq))))
    io;
  Lwt.return ()
;;

let xor_length_differs _ () =
  let io = [ "", "1"; "1", ""; "abc", "ab"; "ab", "abc" ] in
  List.iter
    (fun (v, r) ->
      Alcotest.(
        check
          (option (list char))
          "XORs different length"
          None
          (Sihl_core.Utils.Encryption.xor
             (v |> String.to_seq |> List.of_seq)
             (r |> String.to_seq |> List.of_seq))))
    io;
  Lwt.return ()
;;

let decrypt_with_salt_empty _ () =
  Alcotest.(
    check
      (option (list char))
      "Decrypts empty"
      (Some [])
      (Sihl_core.Utils.Encryption.decrypt_with_salt ~salted_cipher:[] ~salt_length:0));
  Lwt.return ()
;;

let decrypt_with_salt_valid _ () =
  let io =
    [ ("a", "8"), "Y"; ("hello", "12345"), "YW_XZ"; ("{}|[]", " !\"#%"), "[\\^xx" ]
  in
  List.iter
    (fun ((v1, v2), r) ->
      Alcotest.(
        check
          (option (list char))
          "Decrypts valid"
          (Some (v2 |> String.to_seq |> List.of_seq))
          (Sihl_core.Utils.Encryption.decrypt_with_salt
             ~salted_cipher:(v1 ^ r |> String.to_seq |> List.of_seq)
             ~salt_length:(List.length (r |> String.to_seq |> List.of_seq)))))
    io;
  Lwt.return ()
;;

let decrypt_with_salt_length_differs _ () =
  let io = [ "", "1"; "1", ""; "abcde", "ab"; "ab", "abcde" ] in
  List.iter
    (fun (v, r) ->
      Alcotest.(
        check
          (option (list char))
          "Decrypts different length"
          None
          (Sihl_core.Utils.Encryption.decrypt_with_salt
             ~salted_cipher:(r |> String.to_seq |> List.of_seq)
             ~salt_length:(List.length (v |> String.to_seq |> List.of_seq)))))
    io;
  Lwt.return ()
;;

let suite =
  Alcotest_lwt.
    [ ( "encryption"
      , [ test_case "xor empty" `Quick xor_empty
        ; test_case "xor valid" `Quick xor_valid
        ; test_case "xor length differs" `Quick xor_length_differs
        ; test_case "decrypt with salt empty" `Quick decrypt_with_salt_empty
        ; test_case "decrypt with salt valid" `Quick decrypt_with_salt_valid
        ; test_case
            "decrypt with salt length differs"
            `Quick
            decrypt_with_salt_length_differs
        ] )
    ]
;;

let () =
  Unix.putenv "SIHL_ENV" "test";
  Lwt_main.run (Alcotest_lwt.run "encryption" suite)
;;
