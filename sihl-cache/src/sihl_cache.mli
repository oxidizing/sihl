val log_src : Logs.src

module MariaDb : sig
  include Sihl.Contract.Cache.Sig
end

module PostgreSql : sig
  include Sihl.Contract.Cache.Sig
end
