module Core = {
  module Async = SihlCoreAsync;
  module Base64 = SihlCoreBase64;
  module Uuid = SihlCoreUuid;
  module Crypt = SihlCoreCrypt;
  module Error = SihlCoreError;
  module Log = SihlCoreLog;
  module Db = SihlCoreDb;
  module Config = SihlCoreConfig;
  module Http = SihlCoreHttpCore;
  module Email = SihlCoreEmail;
};

module MakeApp = (Persistence: Core.Db.PERSISTENCE) => {
  module Repo = SihlCoreRepo.Make(Persistence);
  module Http = SihlCoreHttp.Make(Persistence);
  module Main = SihlCoreMain.Make(Persistence);
  module Test = Main.Test;
  module Cli = SihlCoreCli.Make(Persistence);
};
