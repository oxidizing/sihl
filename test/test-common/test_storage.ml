open Lwt.Syntax
open Base
open Alcotest_lwt

let alco_file = Alcotest.testable Sihl.Storage.File.pp Sihl.Storage.File.equal

module Make
    (DbService : Sihl.Data.Db.Service.Sig.SERVICE)
    (RepoService : Sihl.Data.Repo.Service.Sig.SERVICE)
    (StorageService : Sihl.Storage.Service.Sig.SERVICE) =
struct
  let fetch_uploaded_file _ () =
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
    let* () = RepoService.clean_all ctx in
    let file_id = Sihl.Data.Id.(random () |> to_string) in
    let file =
      Sihl.Storage.File.make ~id:file_id ~filename:"diploma.pdf" ~filesize:123
        ~mime:"application/pdf"
    in
    let* _ =
      StorageService.upload_base64 ctx ~file ~base64:"ZmlsZWNvbnRlbnQ="
    in
    let* uploaded_file = StorageService.find ctx ~id:file_id in
    let actual_file = uploaded_file |> Sihl.Storage.StoredFile.file in
    Alcotest.(check alco_file "has same file" file actual_file);
    let* actual_blob =
      StorageService.download_data_base64 ctx ~file:uploaded_file
    in
    Alcotest.(check string "has same blob" "ZmlsZWNvbnRlbnQ=" actual_blob);
    Lwt.return ()

  let update_uploaded_file _ () =
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
    let* () = RepoService.clean_all ctx in
    let file_id = Sihl.Data.Id.(random () |> to_string) in
    let file =
      Sihl.Storage.File.make ~id:file_id ~filename:"diploma.pdf" ~filesize:123
        ~mime:"application/pdf"
    in
    let* stored_file =
      StorageService.upload_base64 ctx ~file ~base64:"ZmlsZWNvbnRlbnQ="
    in

    let updated_file =
      Sihl.Storage.StoredFile.set_filename "assessment.pdf" stored_file
    in
    let* actual_file =
      StorageService.update_base64 ctx ~file:updated_file
        ~base64:"bmV3Y29udGVudA=="
    in
    Alcotest.(
      check alco_file "has updated file"
        (Sihl.Storage.StoredFile.file updated_file)
        (Sihl.Storage.StoredFile.file actual_file));
    let* actual_blob =
      StorageService.download_data_base64 ctx ~file:stored_file
    in
    Alcotest.(check string "has updated blob" "bmV3Y29udGVudA==" actual_blob);
    Lwt.return ()

  let test_suite =
    ( "storage",
      [
        test_case "upload file" `Quick fetch_uploaded_file;
        test_case "update file" `Quick update_uploaded_file;
      ] )
end
