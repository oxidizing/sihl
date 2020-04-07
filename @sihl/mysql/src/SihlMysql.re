module Persistence: SihlMysql_Sihl.Common.Db.PERSISTENCE = {
  module Database = SihlMysql_Persistence.Database;
  module Connection = SihlMysql_Persistence.Connection;
  module Migration = SihlMysql_Migration;
};
