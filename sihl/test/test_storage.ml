open Base

let ( let* ) = Lwt.bind

let alco_file = Alcotest.testable Sihl.Storage.File.pp Sihl.Storage.File.equal

let upload_file _ () =
  let* () =
    Sihl.Test.register_services [ Sihl.Migration.mariadb; Sihl.Storage.mariadb ]
  in
  let file_id = Sihl.Id.(random () |> to_string) in
  let file =
    Sihl.Storage.File.make ~id:file_id ~filename:"diploma.pdf" ~filesize:123
      ~mime:"application/pdf"
  in
  let* req = Sihl.Test.request_with_connection () in
  let* uploaded_file =
    Sihl.Storage.upload_base64 req ~file ~base64:"filecontentinbase64"
    |> Lwt.map Result.ok_or_failwith
  in
  let actual = Sihl.Storage.UploadedFile.file uploaded_file in
  Alcotest.(check alco_file "has same file" file actual);
  Lwt.return ()
