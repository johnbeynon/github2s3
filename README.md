# Github to S3

Simple tool to interface to the Github API to retrieve your repos list, perform
a deep clone of the repos, zip and then transfer to S3.

Intelligently compares last push date to the repo against the age of file on S3 to decide whether to
perform a backup of the repo.

# Setup:

* Copy env_sample to .env
* Update .env as required to suit
* `REPOS_TO_SKIP` should be a comma seperated list of values

# Usage:

Use `foreman run` to load environment variables to pass to task:

```
foreman run ruby github2s3.rb
```

# TODO:

make backup task into rake task with options (skip repos etc)
