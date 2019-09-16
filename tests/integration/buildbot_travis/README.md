# An example master-worker configuration

This integration test creates a `buildbot` master and two workers. In addition
to example build from `buildbot` default installation, it also creates other
builds.

To run the test do:

```
bundle exec rake test
```

which creates the environment, runs the tests, and destroy it.

To poke around the environment, run:

```
bundle exec rake prepare
```

To see the build status, visit
[http://192.168.21.200:8010](http://192.168.21.200:8010).

To destroy the environment, run:

```
bundle exec rake clean
```
