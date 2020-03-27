module Persistence: Sihl.Core.Db.PERSISTENCE = {
  module Database = MysqlPersistence.Database;
  module Connection = MysqlPersistence.Connection;
  module Migration = MysqlMigration;
};
