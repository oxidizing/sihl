let ( let* ) = Lwt.bind

let upload_file _ () =
  (* let* () =
   *   Sihl.Test.register_services [ Sihl.Migration.mariadb; Sihl.Storage.mariadb ]
   * in *)
  Lwt.return ()
