Check out http://shopify.github.com/dashing for more information.

## How to deploy

### Once at first time
```sh
git clone https://github.com/orangain/mydashboard.git
cd mydashboard
bundle install --path=vendor/bundle
cd chef-repo
knife solo prepare HOST
knife solo cook HOST nodes/appserver.json
cd ..
bundle exec cap ENVIRONMENT deploy:setup
```

### When application code is updated
```sh
bundle exec cap ENVIRONMENT deploy
```

### When recipes are updated
```sh
knife solo cook HOST nodes/appserver.json
```
