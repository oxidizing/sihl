module App = Sihl_core.App

(* Core services & Utils *)
module Configuration = Sihl_core.Configuration
module Command = Sihl_core.Command
module Log = Sihl_core.Log
module Utils = Sihl_core.Utils
module Time = Sihl_core.Time

(* Schedule module *)
module Schedule = struct
  include Sihl_contract.Schedule
  include Sihl_facade.Schedule

  module Setup = struct
    let default = (module Sihl_core.Schedule : Sihl_contract.Schedule.Sig)

    let register ?(implementation = default) () =
      Sihl_facade.Schedule.register implementation
    ;;
  end
end

module Cleaner = struct
  include Sihl_core.Cleaner

  module Setup = struct
    let register = Sihl_core.Cleaner.register
  end
end

(* Web module *)
module Web = struct
  module Route = Sihl_contract.Http
  include Sihl_web

  module Setup = struct
    let opium = (module Sihl_web.Http : Sihl_contract.Http.Sig)
    let register routers = Sihl_web.Http.register ~routers ()
  end
end

(* Database module *)
module Database = struct
  include Sihl_contract.Database
  include Sihl_persistence.Database

  module Setup = struct
    let register = Sihl_persistence.Database.register
  end
end

(* Migration module *)
module Migration = struct
  include Sihl_contract.Migration
  include Sihl_facade.Migration

  module Setup = struct
    let register = Sihl_facade.Migration.register

    let postgresql =
      (module Sihl_persistence.Migration.PostgreSql : Sihl_contract.Migration.Sig)
    ;;

    let mariadb =
      (module Sihl_persistence.Migration.MariaDb : Sihl_contract.Migration.Sig)
    ;;
  end
end

(* User & Security module *)
module Security = struct
  module User = struct
    include Sihl_contract.User
    include Sihl_facade.User

    module Setup = struct
      let register = Sihl_facade.User.register
      let postgresql = (module Sihl_user.User.PostgreSql : Sihl_contract.User.Sig)
      let mariadb = (module Sihl_user.User.MariaDb : Sihl_contract.User.Sig)
    end
  end

  module Session = struct
    include Sihl_contract.Session
    include Sihl_facade.Session

    module Setup = struct
      let register = Sihl_facade.Session.register
      let postgresql = (module Sihl_user.Session.PostgreSql : Sihl_contract.Session.Sig)
      let mariadb = (module Sihl_user.Session.MariaDb : Sihl_contract.Session.Sig)
    end
  end

  module Password_reset = struct
    include Sihl_contract.Password_reset
    include Sihl_facade.Password_reset

    module Setup = struct
      let default = (module Sihl_user.Password_reset : Sihl_contract.Password_reset.Sig)

      let register ?(implementation = default) () =
        Sihl_facade.Password_reset.register implementation
      ;;
    end
  end

  module Token = struct
    include Sihl_contract.Token
    include Sihl_facade.Token

    module Setup = struct
      let register = Sihl_facade.Token.register
      let mariadb = (module Sihl_token.Token.MariaDb : Sihl_contract.Token.Sig)
    end
  end

  module Random = Sihl_facade.Random
  module Authz = Sihl_user.Authz
end

(* Email module *)
module Email = struct
  include Sihl_contract.Email
  include Sihl_facade.Email

  module Setup = struct
    let register = Sihl_facade.Email.register
    let smtp = (module Sihl_email.Smtp : Sihl_contract.Email.Sig)
    let sendgid = (module Sihl_email.SendGrid : Sihl_contract.Email.Sig)
    let queued = (module Sihl_email.Queued : Sihl_contract.Email.Sig)
  end

  module Template = struct
    include Sihl_contract.Email_template
    include Sihl_facade.Email_template

    module Setup = struct
      let register = Sihl_facade.Email_template.register

      let postgresql =
        (module Sihl_email.Template.PostgreSql : Sihl_contract.Email_template.Sig)
      ;;

      let mariadb =
        (module Sihl_email.Template.MariaDb : Sihl_contract.Email_template.Sig)
      ;;
    end
  end
end

(* Queue module *)
module Queue = struct
  include Sihl_facade.Queue

  module Setup = struct
    let register = Sihl_facade.Queue.register
    let mariadb = (module Sihl_queue.MariaDb : Sihl_contract.Queue.Sig)
    let memory = (module Sihl_queue.Memory : Sihl_contract.Queue.Sig)
  end
end

(* Storage module *)
module Storage = struct
  include Sihl_facade.Storage

  module Setup = struct
    let register = Sihl_facade.Queue.register
    let mariadb = (module Sihl_storage.MariaDb : Sihl_contract.Storage.Sig)
  end
end
