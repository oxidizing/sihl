module Make = (Persistence: SihlCoreDbCore.PERSISTENCE) => {
  module Migration = SihlCoreDbMigration.Make(Persistence);
  module Repo = SihlCoreDbRepo.Make(Persistence.Connection);
};
