module MariaDb : sig
  include Sihl.Contract.Token.Sig
end

module PostgreSql : sig
  include Sihl.Contract.Token.Sig
end

module JwtInMemory : sig
  include Sihl.Contract.Token.Sig
end

module JwtMariaDb : sig
  include Sihl.Contract.Token.Sig
end

module JwtPostgreSql : sig
  include Sihl.Contract.Token.Sig
end
