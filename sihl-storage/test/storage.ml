open Lwt.Syntax
open Alcotest_lwt

let file_equal f1 f2 =
  String.equal
    (Format.asprintf "%a" Sihl_storage.pp_file f1)
    (Format.asprintf "%a" Sihl_storage.pp_file f2)
;;

let alco_file = Alcotest.testable Sihl_storage.pp_file file_equal

module Make (StorageService : Sihl.Contract.Storage.Sig) = struct
  let fetch_uploaded_file _ () =
    let* () = Sihl.Cleaner.clean_all () in
    let file_id = Uuidm.v `V4 |> Uuidm.to_string in
    let file =
      Sihl.Contract.Storage.
        { id = file_id
        ; filename = "diploma.pdf"
        ; filesize = 123
        ; mime = "application/pdf"
        }
    in
    let* _ = StorageService.upload_base64 file ~base64:"ZmlsZWNvbnRlbnQ=" in
    let* uploaded_file = StorageService.find ~id:file_id in
    let actual_file = uploaded_file.Sihl.Contract.Storage.file in
    Alcotest.(check alco_file "has same file" file actual_file);
    let* actual_blob = StorageService.download_data_base64 uploaded_file in
    Alcotest.(check string "has same blob" "ZmlsZWNvbnRlbnQ=" actual_blob);
    Lwt.return ()
  ;;

  let update_uploaded_file _ () =
    let* () = Sihl.Cleaner.clean_all () in
    let file_id = Uuidm.v `V4 |> Uuidm.to_string in
    let file =
      Sihl.Contract.Storage.
        { id = file_id
        ; filename = "diploma.pdf"
        ; filesize = 123
        ; mime = "application/pdf"
        }
    in
    let* stored_file =
      StorageService.upload_base64 file ~base64:"ZmlsZWNvbnRlbnQ="
    in
    let updated_file =
      Sihl_storage.set_filename_stored "assessment.pdf" stored_file
    in
    let* actual_file =
      StorageService.update_base64 updated_file ~base64:"bmV3Y29udGVudA=="
    in
    Alcotest.(
      check
        alco_file
        "has updated file"
        updated_file.Sihl.Contract.Storage.file
        actual_file.Sihl.Contract.Storage.file);
    let* actual_blob = StorageService.download_data_base64 stored_file in
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
end
