type t('database, 'endpoint, 'cliCommand) = {
  name: string,
  namespace: string,
  routes: 'database => list('endpoint),
  migration: Common_Db.Migration.t,
  commands: list('cliCommand),
  configurationSchema: Common_Config.Schema.t,
};
