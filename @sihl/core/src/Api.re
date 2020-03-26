module Core = {
  module Async = SihlCoreAsync;
  module Base64 = SihlCoreBase64;
  module Uuid = SihlCoreUuid;
  module Bcrypt = SihlCoreBcrypt;
  module Error = SihlCoreError;
  module Log = SihlCoreLog;
  module Db = SihlCoreDbCore;
  module Config = SihlCoreConfig;
};

module MakeApp = (Persistence: Core.Db.PERSISTENCE) => {
  module Db = SihlCoreDb.Make(Persistence);
  module Http = SihlCoreHttp.Make(Persistence);
  module Main = SihlCoreMain.Make(Persistence);
  module Test = Main.Test;
  module Cli = SihlCoreCli.Make(Persistence);
};
