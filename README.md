# ansible-role-buildbot

Install `buildbot` master. For `buildbot` worker, use
`trombik.buildbot_worker` role.

# Requirements

None

# Role Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `buildbot_user` | user of `buildbot` | `buildbot` |
| `buildbot_group` | group of `buildbot` | `buildbot` |
| `buildbot_package` | package name of `buildbot` | `{{ __buildbot_package }}` |
| `buildbot_extra_packages` | list of additional packages to install | `{{ __buildbot_extra_package }}` |
| `buildbot_extra_pip_packages` | list of additional pip packages to install | `[]` |
| `buildbot_service` | name of `buildbot` service | `{{ __buildbot_service }}` |
| `buildbot_root_dir` | path to root directory of `buildbot`, usually same as `buildbot_conf_dir` | `{{ __buildbot_root_dir }}` |
| `buildbot_conf_dir` | path to directory where configuration files are | `{{ buildbot_root_dir }}` |
| `buildbot_conf_file` | path to the configuration file | `{{ buildbot_conf_dir }}/master.cfg` |
| `buildbot_executable` | path to `buildbot` executable | `{{ __buildbot_executable }}` |
| `buildbot_master_cfg_content` content of the configuration file | | `""` |
| `buildbot_flags` | content of startup configuration file | `""` |
| `buildbot_create_master_flags` | command line flags to pass `buildbot create-master` command | `-r` |

## Debian

| Variable | Default |
|----------|---------|
| `__buildbot_package` | `python3-buildbot` |
| `__buildbot_extra_package` | `[]` |
| `__buildbot_service` | `buildmaster@default` |
| `__buildbot_root_dir` | `/var/lib/buildbot` |
| `__buildbot_executable` | `/usr/bin/buildbot` |

## FreeBSD

| Variable | Default |
|----------|---------|
| `__buildbot_package` | `devel/py-buildbot` |
| `__buildbot_extra_packages` | `["devel/py-buildbot-www", "devel/py-buildbot-console-view", "devel/py-buildbot-grid-view", "devel/py-buildbot-waterfall-view"]` |
| `__buildbot_service` | `buildbot` |
| `__buildbot_root_dir` | `/usr/local/buildbot` |
| `__buildbot_executable` | `/usr/local/bin/buildbot` |

## RedHat

| Variable | Default |
|----------|---------|
| `__buildbot_package` | `buildbot[bundle]` |
| `__buildbot_extra_packages` | `[]` |
| `__buildbot_service` | `buildbot` |
| `__buildbot_root_dir` | `/var/lib/buildbot` |
| `__buildbot_executable` | `/usr/local/bin/buildbot` |

# Dependencies

None

# Example Playbook

```yaml
---
- hosts: localhost
  roles:
    - name: trombik.freebsd_pkg_repo
      when: ansible_os_family == 'FreeBSD'
    - name: trombik.redhat_repo
      when: ansible_os_family == 'RedHat'
    - ansible-role-buildbot
  vars:
    freebsd_pkg_repo:
      # disable the default repository. `quarterly` does not have buildbot 2.x yet
      FreeBSD:
        enabled: "false"
        state: present
      FreeBSD_latest:
        enabled: "true"
        state: present
        url: pkg+https://pkg.FreeBSD.org/${ABI}/latest
        signature_type: fingerprints
        fingerprints: /usr/share/keys/pkg
        mirror_type: srv

    redhat_repo:
      epel:
        mirrorlist: "http://mirrors.fedoraproject.org/mirrorlist?repo=epel-{{ ansible_distribution_major_version }}&arch={{ ansible_architecture }}"
        gpgcheck: yes
        enabled: yes
        description: EPEL

    buildbot_conf_dir: "{% if ansible_os_family == 'Debian' %}{{ buildbot_root_dir }}/masters/default{% else %}{{ buildbot_root_dir }}{% endif %}"
    buildbot_flags_ubuntu: |
      MASTER_ENABLED[1]=1
      MASTER_NAME[1]="default"
      MASTER_USER[1]="buildbot"
      MASTER_BASEDIR[1]="{{ buildbot_conf_dir }}"
      MASTER_OPTIONS[1]=""
      MASTER_PREFIXCMD[1]=""
    buildbot_flags_freebsd: |
      buildbot_basedir="{{ buildbot_conf_dir }}"
      buildbot_user="{{ buildbot_user }}"

    buildbot_flags: "{% if ansible_os_family == 'FreeBSD' %}{{ buildbot_flags_freebsd }}{% elif ansible_os_family == 'Debian' %}{{ buildbot_flags_ubuntu }}{% endif %}"
    buildbot_master_cfg_content: |
      from buildbot.plugins import *
      c = BuildmasterConfig = {}
      c['workers'] = [worker.Worker("example-worker", "pass")]
      c['protocols'] = {'pb': {'port': 9989}}
      c['change_source'] = []
      c['change_source'].append(changes.GitPoller(
              'git://github.com/buildbot/hello-world.git',
              workdir='gitpoller-workdir', branch='master',
              pollInterval=300))
      c['schedulers'] = []
      c['schedulers'].append(schedulers.SingleBranchScheduler(
                                  name="all",
                                  change_filter=util.ChangeFilter(branch='master'),
                                  treeStableTimer=None,
                                  builderNames=["runtests"]))
      c['schedulers'].append(schedulers.ForceScheduler(
                                  name="force",
                                  builderNames=["runtests"]))
      factory = util.BuildFactory()
      factory.addStep(steps.Git(repourl='git://github.com/buildbot/hello-world.git', mode='incremental'))
      factory.addStep(steps.ShellCommand(command=["trial", "hello"],
                                         env={"PYTHONPATH": "."}))
      c['builders'] = []
      c['builders'].append(
          util.BuilderConfig(name="runtests",
            workernames=["example-worker"],
            factory=factory))
      c['services'] = []
      c['title'] = "Hello World CI"
      c['titleURL'] = "https://buildbot.github.io/hello-world/"
      c['buildbotURL'] = "http://localhost:8010/"
      c['www'] = dict(port=8010,
                      plugins=dict(waterfall_view={}, console_view={}, grid_view={}))
      c['db'] = {
          'db_url' : "sqlite:///state.sqlite",
      }

    buildbot_extra_packages: "{% if ansible_os_family == 'Debian' %}[ 'python3-pip' ]{% elif ansible_os_family == 'RedHat' %}[ 'python36-pip', 'python36-devel' ]{% else %}[ 'devel/py-buildbot-www' ]{% endif %}"
    buildbot_extra_pip_packages: "{% if ansible_os_family == 'Debian' %}[ 'buildbot-www', 'buildbot-waterfall-view', 'buildbot-console-view', 'buildbot-grid-view' ]{% else %}[]{% endif %}"
```

# License

```
Copyright (c) 2019 Tomoyuki Sakurai <y@trombik.org>

Permission to use, copy, modify, and distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```

# Author Information

Tomoyuki Sakurai <y@trombik.org>

This README was created by [qansible](https://github.com/trombik/qansible)
