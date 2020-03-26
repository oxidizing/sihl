module Make = (Persistence: SihlCoreDbCore.PERSISTENCE) => {
  module Database = SihlCoreDbDatabase.Make(Persistence);
  module Migration = SihlCoreDbMigration.Make(Persistence);
  module Repo = SihlCoreDbRepo.Make(Persistence.Connection);
};
