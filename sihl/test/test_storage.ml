open Base

let ( let* ) = Lwt.bind

let alco_file = Alcotest.testable Sihl.Storage.File.pp Sihl.Storage.File.equal

let upload_file _ () =
  let* () = Sihl.Run.Manage.clean () in
  let* () =
    Sihl.Test.register_services [ Sihl.Migration.mariadb; Sihl.Storage.mariadb ]
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
    Sihl.Storage.get_file req ~id:file_id |> Lwt.map Result.ok_or_failwith
  in
  let actual =
    Option.value_exn uploaded_file ~message:"No uploaded file found"
    |> Sihl.Storage.UploadedFile.file
  in
  Alcotest.(check alco_file "has same file" file actual);
  Lwt.return ()
