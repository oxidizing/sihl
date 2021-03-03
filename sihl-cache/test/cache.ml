open Lwt.Syntax
open Alcotest_lwt

module Make (CacheService : Sihl.Contract.Cache.Sig) = struct
  let create_and_read_cache _ () =
    let* () = Sihl.Cleaner.clean_all () in
    let* () = CacheService.set ("foo", Some "bar") in
    let* () = CacheService.set ("fooz", Some "baz") in
    let* value = CacheService.find "foo" in
    Alcotest.(check (option string) "has value" (Some "bar") value);
    let* value = CacheService.find "fooz" in
    Alcotest.(check (option string) "has value" (Some "baz") value);
    Lwt.return ()
  ;;

  let update_cache _ () =
    let* () = Sihl.Cleaner.clean_all () in
    let* () = CacheService.set ("foo", Some "bar") in
    let* () = CacheService.set ("fooz", Some "baz") in
    let* value = CacheService.find "foo" in
    Alcotest.(check (option string) "has value" (Some "bar") value);
    let* () = CacheService.set ("foo", Some "updated") in
    let* value = CacheService.find "foo" in
    Alcotest.(check (option string) "has value" (Some "updated") value);
    let* () = CacheService.set ("foo", None) in
    let* value = CacheService.find "foo" in
    Alcotest.(check (option string) "has value" None value);
    (* Make sure setting value that is None to None works as well *)
    let* () = CacheService.set ("foo", None) in
    let* value = CacheService.find "foo" in
    Alcotest.(check (option string) "has value" None value);
    Lwt.return ()
  ;;

  let suite =
    [ ( "cache"
      , [ test_case "create and read" `Quick create_and_read_cache
        ; test_case "update" `Quick update_cache
        ] )
    ]
  ;;
end
