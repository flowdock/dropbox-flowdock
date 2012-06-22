# Dropbox integration for Flowdock

Polling framework for integrating external services to Flowdock. Contains an example poller for Dropbox integration.

## Requirements

  * Server with Ruby+RubyGems+bundler installed (tested with Ruby 1.9.3)
  * Dropbox account with access to the folders you want to track

## Deployment

### General instructions

  * Checkout the code from Github and run `bundle install`
  * Go to [My apps](https://www.dropbox.com/developers/apps) in Dropbox while logged in with the account
  * Create a new app with full access to the Dropbox account (name and description can be anything)
  * After creating the app you should see App key and App secret tokens. Copy those into the `sample.env` file in the checked out repository (into APP_KEY and APP_SECRET variables).
  * run `rake dropbox:authorize` and enter your App key and App secret (referenced as Consumer token and Consumer secret)
  * The rake task will give you a link for authorizing the app to access your Dropbox account
  * Now go back to the rake task and press Enter to continue. You should now see user tokens below, copy them to `sample.env` (into USER_TOKEN & USER_SECRET variables).
  * For each flow you want to have notified you must enter the flow's API token to FLOW_TOKENS variable in `sample.env`. Just head to [Account tokens](https://flowdock.com/account/tokens) in order to retrieve tokens for your flows. Copy the tokens to FLOW_TOKENS variable, separated by commas.
  * Symlink or just rename `sample.env` as `.env`
  * run `bundle exec foreman start` and you are done!

### Heroku

Requirements:
 * Signup & install Heroku Toolbelt
 * Install heroku-config

```
heroku plugins:install git://github.com/ddollar/heroku-config.git
```

Checkout flowdock-dropbox from Github and setup Heroku app:
```
git clone https://github.com/flowdock/dropbox-flowdock.git
heroku create
```

Push to Heroku:
```
git push heroku master
```

Create .env file with your configuration (see above instructions about linking your Dropbox account) and push it to Heroku:
```
heroku config:push
```

Finally, start a worker for the app:
```
heroku ps:scale app=1
```

See logs for more information:
```
heroku logs
```

More info about Heroku deployment: https://devcenter.heroku.com/articles/ruby
