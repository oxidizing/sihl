module Authn = Sihl_authn
module User = Sihl_user
module Http = Sihl_http
open Lwt.Syntax

module Make (AuthnService : Authn.Sig.SERVICE) (UserService : User.Sig.SERVICE) = struct
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
    Opium_kernel.Rock.Middleware.create ~name:"authn_session" ~filter
  ;;
end
