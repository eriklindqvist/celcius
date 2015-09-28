# Celcius
Temperature API

## Install
### Prerequisites
* Ruby, Rubygems and Bundler

### Development
* `# bundle install --without=migration production`
* `# shotgun -s thin`

### Production
* To simply start, execute `# bundle install --without=migration development`
* and then `RACK_ENV=production unicorn -c unicorn.rb`
* or simply `./run.sh`

### Console
* run `irb -r ./app.rb`

## Migrating
To migrate data from an old MySQL database, first configure your MongoDB connection in `mongoid.yml` and your MySQL connection inside the `migration.rb` file.
Bundle in the migration gems with:
* `# bundle install --with=migration`
Then run the following command:
* `# ruby ./migrate.rb`
The environment is defined in the RACK_ENV environment variable, and the default environment is "migration", and uses the same mongo config as the development environment as default.
