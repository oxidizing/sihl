module Persistence =
  SihlCore.SihlCoreDbCore.Make(SihlCore.SihlCoreDbMysql.Mysql);

module Core = {
  include SihlCore.SihlCore;
  include SihlCore.SihlCore.Make(Persistence);
};
