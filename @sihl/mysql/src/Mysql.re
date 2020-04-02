module Persistence: Sihl.Common.Db.PERSISTENCE = {
  module Database = Mysql_Persistence.Database;
  module Connection = Mysql_Persistence.Connection;
  module Migration = Mysql_Migration;
};
