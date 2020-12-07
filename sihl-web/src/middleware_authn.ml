module User = Sihl_type.User
open Lwt.Syntax

module Make
    (AuthnService : Sihl_contract.Authn.Sig)
    (UserService : Sihl_contract.User.Sig) =
struct
  let session () =
    let filter handler req =
      match Middleware_session.find_opt req with
      | Some session ->
        let* user = AuthnService.find_user_in_session_opt session in
        (match user with
        | Some user ->
          let req = Middleware_user.set user req in
          handler req
        | None -> handler req)
      | None -> handler req
    in
    Rock.Middleware.create ~name:"authn.session" ~filter
  ;;
end
