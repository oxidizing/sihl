module App : sig
  include module type of Sihl_core.App
end

module Configuration : sig
  include module type of Sihl_core.Configuration
end

module Command : sig
  include module type of Sihl_core.Command
end

module Log : sig
  include module type of Sihl_core.Log
end

module Time : sig
  include module type of Sihl_core.Time
end

module Authz : sig
  include module type of Sihl_user.Authz
end

module Schedule : sig
  include module type of Sihl_facade.Schedule

  val register
    :  ?implementation:(module Sihl_contract.Schedule.Sig)
    -> unit
    -> Sihl_core.Container.Service.t

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
  module Authentication : sig
    include module type of Sihl_web.Authentication
  end

  module Authorization : sig
    include module type of Sihl_web.Authorization
  end

  module Bearer_token : sig
    include module type of Sihl_web.Bearer_token
  end

  module Csrf : sig
    include module type of Sihl_web.Csrf
  end

  module Error : sig
    include module type of Sihl_web.Error
  end

  module Flash : sig
    include module type of Sihl_web.Flash
  end

  module Form : sig
    include module type of Sihl_web.Form
  end

  module Html : sig
    include module type of Sihl_web.Htmx
  end

  module Http : sig
    include module type of Sihl_web.Http
  end

  module Id : sig
    include module type of Sihl_web.Id
  end

  module Json : sig
    include module type of Sihl_web.Json
  end

  module Session : sig
    include module type of Sihl_web.Session
  end

  module Static : sig
    include module type of Sihl_web.Static
  end

  module User : sig
    include module type of Sihl_web.User
  end

  val register : Sihl_contract.Http.router list -> Sihl_core.Container.Service.t
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
      -> Sihl_core.Container.Service.t

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
