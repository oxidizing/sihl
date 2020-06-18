let ( let* ) = Lwt.bind

let upload_file _ () =
  let* () = Sihl.Test.register_service Sihl.Storage.mariadb in
  Lwt.return ()
