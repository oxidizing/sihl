open Lwt.Syntax
open Alcotest_lwt

module Make (TokenService : Sihl.Token.Sig.SERVICE) = struct
  let create_and_find_token _ () =
    let* () = Sihl.Repository.Service.clean_all () in
    let* created = TokenService.create ~kind:"test" ~data:"foo" () in
    let created_value = Sihl.Token.value created in
    let* found = TokenService.find created_value in
    let () = Alcotest.(check Sihl.Token.alco "Has created session" created found) in
    Lwt.return ()
  ;;

  let test_suite =
    "token", [ test_case "create and find token" `Quick create_and_find_token ]
  ;;
end
