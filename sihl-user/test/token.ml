open Lwt.Syntax
open Alcotest_lwt

module Make (TokenService : Sihl_contract.Token.Sig) = struct
  let create_and_find_token _ () =
    let* () = Sihl_persistence.Repository.clean_all () in
    let* created = TokenService.create ~kind:"test" ~data:"foo" () in
    let created_value = Sihl_type.Token.value created in
    let* found = TokenService.find created_value in
    let () = Alcotest.(check Sihl_type.Token.alco "Has created session" created found) in
    Lwt.return ()
  ;;

  let suite =
    [ "token", [ test_case "create and find token" `Quick create_and_find_token ] ]
  ;;
end