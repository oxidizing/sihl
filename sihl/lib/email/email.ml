include Email_model

module Service = struct
  module Template = Email_sig.Template
  module ConfigProvider = Email_sig.ConfigProvider

  module type SERVICE = Email_sig.SERVICE

  let key = Email_sig.key
end

let send req email =
  let (module EmailService : Service.SERVICE) =
    Core.Container.fetch_exn Service.key
  in
  EmailService.send req email
