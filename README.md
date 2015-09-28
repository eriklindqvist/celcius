# Celcius
Temperature API

## Install
1. Install ruby and bundler
2. Run `bundle update`
3. Running
  * For development, run `shotgun -s thin`
  * For production, run `unicorn -c unicorn.rb`
  * For a console, run `irb -r ./app.rb`

## Migrating
To migrate data from an old MySQL database, first configure your MongoDB connection in `mongoid.yml` and your MySQL connection inside the `migration.rb` file.
Bundle in the migration gems with:
  `# bundle install --with=migration`
Then run the following command:
  `# ruby ./migrate.rb`
The environment is defined in the RACK_ENV environment variable, and the default environment is "migration", and uses the same mongo config as the development environment as default.
