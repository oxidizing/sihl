module Persistence =
  SihlCore.SihlCoreDbCore.Make(SihlMysql.Persistence.Mysql);

module Core = {
  include SihlCore.SihlCore;
  include SihlCore.SihlCore.Make(Persistence);
};
