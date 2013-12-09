# OAuth/Canvas Example

An example Sinatra application that is launched into with LTI and then uses the
Canvas API to return a course list.

## Getting started

If you've not used Ruby before, you'll need >= v1.9.2 installed and the Bundler
gem (`gem install bundler`). Once you've got these basics out of the way, you
can start the application with the following:

```bash
$ cd /path/to/oauth_example
$ bundle install --local --path vendor
$
$ bundle exec rackup
```

## About this app

The source code is documented, so you can take a look at `oauth_template.rb` if
you have any specific questions about workflow. You can also contact me
directly.
