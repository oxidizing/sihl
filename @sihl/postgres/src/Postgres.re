module Persistence: Sihl.Core.Db.PERSISTENCE = {
  module Database = Postgres_Persistence.Database;
  module Connection = Postgres_Persistence.Connection;
  module Migration = Postgres_Migration;
};
