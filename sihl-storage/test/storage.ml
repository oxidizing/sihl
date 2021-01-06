open Lwt.Syntax
open Alcotest_lwt

let file_equal f1 f2 =
  String.equal
    (Format.asprintf "%a" Sihl_facade.Storage.pp_file f1)
    (Format.asprintf "%a" Sihl_facade.Storage.pp_file f2)
;;

let alco_file = Alcotest.testable Sihl_facade.Storage.pp_file file_equal

let fetch_uploaded_file _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let file_id = Uuidm.v `V4 |> Uuidm.to_string in
  let file =
    Sihl_contract.Storage.
      { id = file_id
      ; filename = "diploma.pdf"
      ; filesize = 123
      ; mime = "application/pdf"
      }
  in
  let* _ = Sihl_facade.Storage.upload_base64 file ~base64:"ZmlsZWNvbnRlbnQ=" in
  let* uploaded_file = Sihl_facade.Storage.find ~id:file_id in
  let actual_file = uploaded_file.Sihl_contract.Storage.file in
  Alcotest.(check alco_file "has same file" file actual_file);
  let* actual_blob = Sihl_facade.Storage.download_data_base64 uploaded_file in
  Alcotest.(check string "has same blob" "ZmlsZWNvbnRlbnQ=" actual_blob);
  Lwt.return ()
;;

let update_uploaded_file _ () =
  let* () = Sihl_core.Cleaner.clean_all () in
  let file_id = Uuidm.v `V4 |> Uuidm.to_string in
  let file =
    Sihl_contract.Storage.
      { id = file_id
      ; filename = "diploma.pdf"
      ; filesize = 123
      ; mime = "application/pdf"
      }
  in
  let* stored_file =
    Sihl_facade.Storage.upload_base64 file ~base64:"ZmlsZWNvbnRlbnQ="
  in
  let updated_file =
    Sihl_facade.Storage.set_filename_stored "assessment.pdf" stored_file
  in
  let* actual_file =
    Sihl_facade.Storage.update_base64 updated_file ~base64:"bmV3Y29udGVudA=="
  in
  Alcotest.(
    check
      alco_file
      "has updated file"
      updated_file.Sihl_contract.Storage.file
      actual_file.Sihl_contract.Storage.file);
  let* actual_blob = Sihl_facade.Storage.download_data_base64 stored_file in
  Alcotest.(check string "has updated blob" "bmV3Y29udGVudA==" actual_blob);
  Lwt.return ()
;;

let suite =
  [ ( "storage"
    , [ test_case "upload file" `Quick fetch_uploaded_file
      ; test_case "update file" `Quick update_uploaded_file
      ] )
  ]
;;
