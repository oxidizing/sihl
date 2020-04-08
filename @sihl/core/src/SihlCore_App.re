type t('database, 'endpoint, 'cliCommand) = {
  name: string,
  namespace: string,
  routes: 'database => list('endpoint),
  migration: SihlCore_Db.Migration.t,
  commands: list('cliCommand),
  configurationSchema: SihlCore_Config.Schema.t,
};
