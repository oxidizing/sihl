include Email_model
module Service = Email_service
module Sig = Email_sig
module Admin = Email_admin

let send req email =
  let (module EmailService : Sig.SERVICE) =
    Core.Container.fetch_service_exn Sig.key
  in
  EmailService.send req email
