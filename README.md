# Dropbox integration for Flowdock

## Install

Requirements:

  * Server with Ruby+RubyGems+bundler installed (tested with Ruby 1.9.3)
  * Dropbox account with access to the folders you want to track

Steps:

  * Checkout the code from Github and deploy to the server
  * run `bundle install`
  * symlink `sample.env` as `.env`: `ln -s sample.env .env`
  * Go to [My apps](https://www.dropbox.com/developers/apps) in Dropbox while logged in with the account
  * Create a new app with full access to the Dropbox account (name and description can be anything)
  * After creating the app you should see App key and App secret tokens. Copy those into the `sample.env` file in the checked out repository (into APP_TOKEN and APP_SECRET variables).
  * run `rake dropbox:authorize` and enter your App key and App secret (referenced as Consumer token and Consumer secret)
  * The rake task will give you a link to authorize the app for your Dropbox account, copy&paste the link to your browser and allow the app to connect
  * Now go back to the rake task and press Enter to continue. You should now see user tokens below, copy them to `sample.env` (into USER_TOKEN & USER_SECRET variables).
  * For each flow you want to have notified you must enter the flow's API token to FLOW_TOKENS variable in `sample.env`. Just head to [Account tokens](https://flowdock.com/account/tokens) in order to retrieve tokens for your flows. Copy the tokens to FLOW_TOKENS variable, separated by commas.
  * run `bundle exec foreman start` and you are done!

