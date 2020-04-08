module Persistence: SihlMysql_Sihl.Core.Db.PERSISTENCE = {
  module Database = SihlMysql_Persistence.Database;
  module Connection = SihlMysql_Persistence.Connection;
  module Migration = SihlMysql_Migration;
};
