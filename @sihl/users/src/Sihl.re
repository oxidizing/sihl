module Core = {
  include SihlCore.Setup.Core;
  include SihlCore.Setup.MakeApp(SihlMysql.Persistence.Mysql);
};
