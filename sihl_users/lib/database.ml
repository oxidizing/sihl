module MariaDb = struct
  module Repository : Contract.REPOSITORY = struct
    include Repository_mariadb
  end

  module Migration : Sihl_core.Contract.Migration.MIGRATION = struct
    include Migration_mariadb
  end
end

module Postgres = struct
  module Repository : Contract.REPOSITORY = struct
    include Repository_postgres
  end

  module Migration : Sihl_core.Contract.Migration.MIGRATION = struct
    include Migration_postgres
  end
end
