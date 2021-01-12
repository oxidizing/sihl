module App = Sihl_core.App

(* Core services & Utils *)
module Configuration = Sihl_core.Configuration
module Command = Sihl_core.Command
module Log = Sihl_core.Log
module Time = Sihl_core.Time
module Authz = Sihl_user.Authz

(* Schedule module *)
module Schedule = struct
  include Sihl_facade.Schedule

  module Implementation = struct
    let default = (module Sihl_core.Schedule : Sihl_contract.Schedule.Sig)
  end

  let register ?(implementation = Implementation.default) () =
    Sihl_facade.Schedule.register implementation
  ;;
end

(* Random module *)
module Random = struct
  include Sihl_facade.Random
end

(* Cleaner module *)
module Cleaner = struct
  include Sihl_core.Cleaner
end

(* Web module *)
module Web = struct
  include Sihl_web

  let register routers = Sihl_web.Http.register ~routers ()
end

(* Database module *)
module Database = struct
  include Sihl_persistence.Database

  (* Migration module *)
  module Migration = struct
    include Sihl_facade.Migration

    module Implementation = struct
      let postgresql =
        (module Sihl_persistence.Migration.PostgreSql
        : Sihl_contract.Migration.Sig)
      ;;

      let mariadb =
        (module Sihl_persistence.Migration.MariaDb : Sihl_contract.Migration.Sig)
      ;;
    end
  end
end

(* User module *)
module User = struct
  include Sihl_facade.User

  module Implementation = struct
    let postgresql = (module Sihl_user.User.PostgreSql : Sihl_contract.User.Sig)
    let mariadb = (module Sihl_user.User.MariaDb : Sihl_contract.User.Sig)
  end

  module Password_reset = struct
    include Sihl_facade.Password_reset

    module Implementation = struct
      let default =
        (module Sihl_user.Password_reset : Sihl_contract.Password_reset.Sig)
      ;;
    end

    let register ?(implementation = Implementation.default) () =
      Sihl_facade.Password_reset.register implementation
    ;;
  end
end

(* Session module*)
module Session = struct
  include Sihl_facade.Session

  module Implementation = struct
    let postgresql =
      (module Sihl_session.PostgreSql : Sihl_contract.Session.Sig)
    ;;

    let mariadb = (module Sihl_session.MariaDb : Sihl_contract.Session.Sig)
  end
end

(* Token module *)
module Token = struct
  include Sihl_facade.Token

  module Implementation = struct
    let mariadb = (module Sihl_token.MariaDb : Sihl_contract.Token.Sig)
    let postgresql = (module Sihl_token.PostgreSql : Sihl_contract.Token.Sig)

    let jwt_in_memory =
      (module Sihl_token.JwtInMemory : Sihl_contract.Token.Sig)
    ;;

    let jwt_mariadb = (module Sihl_token.JwtMariaDb : Sihl_contract.Token.Sig)

    let jwt_postgresql =
      (module Sihl_token.JwtPostgreSql : Sihl_contract.Token.Sig)
    ;;
  end
end

(* Email module *)
module Email = struct
  include Sihl_facade.Email

  module Implementation = struct
    let smtp = (module Sihl_email.Smtp : Sihl_contract.Email.Sig)
    let sendgid = (module Sihl_email.SendGrid : Sihl_contract.Email.Sig)
    let queued = (module Sihl_email.Queued : Sihl_contract.Email.Sig)
  end
end

module Email_template = struct
  include Sihl_facade.Email_template

  module Implementation = struct
    let postgresql =
      (module Sihl_email.Template.PostgreSql : Sihl_contract.Email_template.Sig)
    ;;

    let mariadb =
      (module Sihl_email.Template.MariaDb : Sihl_contract.Email_template.Sig)
    ;;
  end
end

(* Queue module *)
module Queue = struct
  include Sihl_facade.Queue

  module Implementation = struct
    let postgresql = (module Sihl_queue.PostgreSql : Sihl_contract.Queue.Sig)
    let mariadb = (module Sihl_queue.MariaDb : Sihl_contract.Queue.Sig)
    let in_memory = (module Sihl_queue.InMemory : Sihl_contract.Queue.Sig)
  end
end

(* Storage module *)
module Storage = struct
  include Sihl_facade.Storage

  module Implementation = struct
    let mariadb = (module Sihl_storage.MariaDb : Sihl_contract.Storage.Sig)
  end
end
