// help message when there are no params
if (process.argv.length <= 2) {
    const message = `MIGRATION HELP:
node app -e <env> <command>
EXAMPLES:
node app -e local create helloWorld
node app -e local up (-c 1)
node app -e prod up
node app -e prod down
`
    console.log(message);
}
else {
    require('dotenv').config({ path: ['.env.local', '.env'] });
    const dbMigrate = require('db-migrate');
    process.argv.push('--table', 'migrate_table'); // migrate system table
    //
    var dbmig = dbMigrate.getInstance(false); // isModule= false => params taken from yargs
    dbmig.run();
}
