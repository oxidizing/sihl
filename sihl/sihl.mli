module App = Sihl_core.App
module Configuration = Sihl_core.Configuration
module Command = Sihl_core.Command
module Log = Sihl_core.Log
module Time = Sihl_core.Time
module Authz = Sihl_user.Authz

module Schedule : sig
  include module type of Sihl_facade.Schedule

  val register
    :  ?implementation:(module Sihl_contract.Schedule.Sig)
    -> unit
    -> Sihl_core.Container.Service.t list

  module Implementation : sig
    val default : (module Sihl_contract.Schedule.Sig)
  end
end

module Random : sig
  include module type of Sihl_facade.Random
end

module Cleaner : sig
  include module type of Sihl_core.Cleaner
end

module Web : sig
  module Authentication = Sihl_web.Authentication
  module Authorization = Sihl_web.Authorization
  module Bearer_token = Sihl_web.Bearer_token
  module Csrf = Sihl_web.Csrf
  module Error = Sihl_web.Error
  module Flash = Sihl_web.Flash
  module Form = Sihl_web.Form
  module Htmx = Sihl_web.Htmx
  module Http = Sihl_web.Http
  module Id = Sihl_web.Id
  module Json = Sihl_web.Json
  module Session = Sihl_web.Session
  module Static = Sihl_web.Static
  module User = Sihl_web.User

  val register
    :  Sihl_contract.Http.router list
    -> Sihl_core.Container.Service.t list
end

module Database : sig
  include module type of Sihl_persistence.Database

  module Migration : sig
    include module type of Sihl_facade.Migration

    module Implementation : sig
      val postgresql : (module Sihl_contract.Migration.Sig)
      val mariadb : (module Sihl_contract.Migration.Sig)
    end
  end
end

module User : sig
  include module type of Sihl_facade.User

  module Implementation : sig
    val postgresql : (module Sihl_contract.User.Sig)
    val mariadb : (module Sihl_contract.User.Sig)
  end

  module Password_reset : sig
    include module type of Sihl_facade.Password_reset

    val register
      :  ?implementation:(module Sihl_contract.Password_reset.Sig)
      -> unit
      -> Sihl_core.Container.Service.t list

    module Implementation : sig
      val default : (module Sihl_contract.Password_reset.Sig)
    end
  end
end

module Session : sig
  include module type of Sihl_facade.Session

  module Implementation : sig
    val postgresql : (module Sihl_contract.Session.Sig)
    val mariadb : (module Sihl_contract.Session.Sig)
  end
end

module Token : sig
  include module type of Sihl_facade.Token

  module Implementation : sig
    val mariadb : (module Sihl_contract.Token.Sig)
    val postgresql : (module Sihl_contract.Token.Sig)
    val jwt_in_memory : (module Sihl_contract.Token.Sig)
    val jwt_mariadb : (module Sihl_contract.Token.Sig)
    val jwt_postgresql : (module Sihl_contract.Token.Sig)
  end
end

module Email : sig
  include module type of Sihl_facade.Email

  module Implementation : sig
    val smtp : (module Sihl_contract.Email.Sig)
    val sendgid : (module Sihl_contract.Email.Sig)
    val queued : (module Sihl_contract.Email.Sig)
  end
end

module Email_template : sig
  include module type of Sihl_facade.Email_template

  module Implementation : sig
    val postgresql : (module Sihl_contract.Email_template.Sig)
    val mariadb : (module Sihl_contract.Email_template.Sig)
  end
end

module Queue : sig
  include module type of Sihl_facade.Queue

  module Implementation : sig
    val postgresql : (module Sihl_contract.Queue.Sig)
    val mariadb : (module Sihl_contract.Queue.Sig)
    val in_memory : (module Sihl_contract.Queue.Sig)
  end
end

module Storage : sig
  include module type of Sihl_facade.Storage

  module Implementation : sig
    val mariadb : (module Sihl_contract.Storage.Sig)
  end
end
