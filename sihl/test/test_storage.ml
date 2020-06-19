open Base

let ( let* ) = Lwt.bind

let alco_file = Alcotest.testable Sihl.Storage.File.pp Sihl.Storage.File.equal

let fetch_uploaded_file _ () =
  let* () =
    Sihl.Test.register_services
      [ Sihl.Migration.Service.mariadb; Sihl.Storage.Service.mariadb ]
  in
  let file_id = Sihl.Id.(random () |> to_string) in
  let file =
    Sihl.Storage.File.make ~id:file_id ~filename:"diploma.pdf" ~filesize:123
      ~mime:"application/pdf"
  in
  let* req = Sihl.Test.request_with_connection () in
  let* _ =
    Sihl.Storage.upload_base64 req ~file ~base64:"filecontentinbase64"
    |> Lwt.map Result.ok_or_failwith
  in
  let* uploaded_file =
    Sihl.Storage.get_file req ~id:file_id
    |> Lwt.map Result.ok_or_failwith
    |> Lwt.map (fun file ->
           Option.value_exn file ~message:"No uploaded file found")
  in
  let actual_file = uploaded_file |> Sihl.Storage.StoredFile.file in
  Alcotest.(check alco_file "has same file" file actual_file);
  let* actual_blob =
    Sihl.Storage.get_data_base64 req ~file:uploaded_file
    |> Lwt.map Result.ok_or_failwith
    |> Lwt.map (fun file ->
           Option.value_exn file ~message:"No uploaded blob found")
  in
  Alcotest.(check string "has same blob" "filecontentinbase64" actual_blob);
  Lwt.return ()

let update_uploaded_file _ () =
  let* () =
    Sihl.Test.register_services
      [ Sihl.Migration.Service.mariadb; Sihl.Storage.Service.mariadb ]
  in
  let file_id = Sihl.Id.(random () |> to_string) in
  let file =
    Sihl.Storage.File.make ~id:file_id ~filename:"diploma.pdf" ~filesize:123
      ~mime:"application/pdf"
  in
  let* req = Sihl.Test.request_with_connection () in
  let* stored_file =
    Sihl.Storage.upload_base64 req ~file ~base64:"filecontentinbase64"
    |> Lwt.map Result.ok_or_failwith
  in

  let updated_file =
    Sihl.Storage.StoredFile.set_filename "assessment.pdf" stored_file
  in
  let* actual_file =
    Sihl.Storage.update_base64 req ~file:updated_file ~base64:"newcontent"
    |> Lwt.map Result.ok_or_failwith
  in
  Alcotest.(
    check alco_file "has updated file"
      (Sihl.Storage.StoredFile.file updated_file)
      (Sihl.Storage.StoredFile.file actual_file));
  let* actual_blob =
    Sihl.Storage.get_data_base64 req ~file:stored_file
    |> Lwt.map Result.ok_or_failwith
    |> Lwt.map (fun file ->
           Option.value_exn file ~message:"No uploaded blob found")
  in
  Alcotest.(check string "has updated blob" "newcontent" actual_blob);
  Lwt.return ()
