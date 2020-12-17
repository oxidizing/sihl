(* Core *)
module Service = Sihl_core.Container
module App = Sihl_core.App

(* Core services *)
module Configuration = Sihl_core.Configuration
module Command = Sihl_core.Command
module Log = Sihl_core.Log
module Utils = Sihl_core.Utils
module Time = Sihl_core.Time

(* Schedule module *)
module Schedule = struct
  include Sihl_contract.Schedule
  include Sihl_facade.Schedule
end

(* Web module *)
module Web = struct
  module Route = Sihl_contract.Http
  module Http = Sihl_web.Http
  module Middleware = Sihl_web.Middleware
end

(* Persistence module *)
module Persistence = struct
  module Cleaner = Sihl_persistence.Repository

  module Database = struct
    include Sihl_contract.Database
    include Sihl_persistence.Database
  end

  module Migration = struct
    include Sihl_contract.Migration
    include Sihl_persistence.Migration
  end
end

(* User & Security module *)
module Security = struct
  module User = struct
    include Sihl_contract.User
    include Sihl_facade.User
  end

  module Session = struct
    include Sihl_contract.Session
    include Sihl_facade.Session
  end

  module Password_reset = struct
    include Sihl_contract.Password_reset
    include Sihl_facade.Password_reset
  end

  module Authn = struct
    include Sihl_contract.Authn
    include Sihl_facade.Authn
  end

  module Token = struct
    include Sihl_contract.Token
    include Sihl_facade.Token
  end

  module Random = Sihl_core.Random
  module Authz = Sihl_user.Authz
end

(* Email module *)
module Email = struct
  include Sihl_contract.Email
  include Sihl_facade.Email

  module Template = struct
    include Sihl_contract.Email_template
    include Sihl_facade.Email_template
  end
end

(* Queue module *)
module Queue = struct
  module Job = Sihl_contract.Queue_job
  module Job_instance = Sihl_contract.Queue_job_instance
  module Workable_job = Sihl_contract.Queue_workable_job
  include Sihl_facade.Queue
end

(* Storage module *)
module Storage = struct
  module File = Sihl_contract.Storage.File
  module Stored = Sihl_contract.Storage.Stored
  include Sihl_facade.Storage
end
