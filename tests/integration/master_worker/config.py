from buildbot.plugins import *
# vim: ft=python

c = BuildmasterConfig = {}
#
# builders:
c['builders'] = []
#
# ports build
build_pkg = util.BuildFactory()

build_pkg.addStep(steps.Git(
    repourl = 'https://github.com/trombik/freebsd-ports-mini',
    branch = '20190409'))

build_pkg.addStep(steps.ShellCommand(
    name = 'Create PORT_DBDIR',
    command = 'mkdir -p /usr/local/buildbot_worker/pkg/build/var/db/ports'))

build_pkg.addStep(steps.ShellCommand(
    name = 'make',
    env = {'PORT_DBDIR': '/usr/local/buildbot_worker/pkg/build/var/db/ports'},
    command = 'make -C ports-mgmt/pkg',
    description = 'make pkg from ports'))

build_pkg.addStep(steps.ShellCommand(
    name='make clean',
    env={'PORT_DBDIR': '/usr/local/buildbot_worker/pkg/build/var/db/ports'},
    command='make -C ports-mgmt/pkg clean',
    description='make clean'))

# pio build
build_pio = util.BuildFactory()
build_pio.addStep(steps.Git(
    repourl = 'https://github.com/platformio/platformio-examples',
    branch = 'master'))
build_pio.addStep(steps.ShellCommand(
    name = 'clean',
    command = 'rm -rf build/wiring-blink/.pioenvs'))
build_pio.addStep(steps.ShellCommand(
    name = 'pio run',
    command = 'pio run -vv -e nodemcu',
    workdir = 'build/wiring-blink',
    env = {
        'PATH': '/usr/local/buildbot_worker/.local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin/',
        'HOME': '/usr/local/buildbot_worker'}))

build_runtests = util.BuildFactory()
build_runtests.addStep(
        steps.Git(
            repourl='git://github.com/buildbot/hello-world.git',
            mode='incremental'))
build_runtests.addStep(
        steps.ShellCommand(
            command = ["trial", "hello"],
            env={"PYTHONPATH": "."}))

c['builders'].append(
        util.BuilderConfig(
            name = "runtests",
            workernames = ["worker1"],
            factory = build_runtests))
c['builders'].append(
        util.BuilderConfig(
            name = 'pkg',
            workernames = ['worker1'],
            factory = build_pkg))
c['builders'].append(
        util.BuilderConfig(
            name = 'pio',
            workernames = ['worker1'],
            factory = build_pio))

# schedulers
c['schedulers'] = []
c['schedulers'].append(schedulers.SingleBranchScheduler(
    name = "all",
    change_filter = util.ChangeFilter(branch='master'),
    treeStableTimer = None,
    builderNames = ["runtests"]))
c['schedulers'].append(schedulers.ForceScheduler(
    name="force",
    builderNames=["runtests"]))
c['schedulers'].append(schedulers.ForceScheduler(
    name="force_pio",
    builderNames=["pio"]))
c['schedulers'].append(schedulers.Periodic(
    name = "hourly",
    builderNames = ["pkg", "pio"],
    periodicBuildTimer=3600))

# master configuration
c['workers'] = [worker.Worker("worker1", "pass")]
c['protocols'] = {'pb': {'port': 9989}}

c['change_source'] = []
c['change_source'].append(changes.GitPoller(
      'git://github.com/buildbot/hello-world.git',
      workdir='gitpoller-workdir', branch='master',
      pollInterval=300))

c['change_source'].append(changes.GitPoller(
  'https://github.com/trombik/freebsd-ports-mini',
  workdir='ports',
  branch='20190409',
  pollAtLaunch=True,
  gitbin='/usr/local/bin/git',
  pollInterval=300))


c['services'] = []
c['title'] = "Hello World CI"
c['titleURL'] = "https://buildbot.github.io/hello-world/"
c['buildbotURL'] = "http://{{ ansible_em1.ipv4[0].address }}:8010/"
c['www'] = dict(port=8010,
              plugins=dict(waterfall_view={}, console_view={}, grid_view={}))
c['db'] = {
  'db_url' : "sqlite:///state.sqlite",
}
