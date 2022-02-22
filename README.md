# `trombik.buildbot`

[![kitchen](https://github.com/trombik/ansible-role-buildbot/actions/workflows/kitchen.yml/badge.svg)](https://github.com/trombik/ansible-role-buildbot/actions/workflows/kitchen.yml)
[![molecule](https://github.com/trombik/ansible-role-buildbot/actions/workflows/molecule.yml/badge.svg)](https://github.com/trombik/ansible-role-buildbot/actions/workflows/molecule.yml)

Install `buildbot` master. For `buildbot` worker, use
[`trombik.buildbot_worker`](https://github.com/trombik/ansible-role-buildbot_worker) role.

A complete master-worker setup can be found at
[molecule/default/playbooks](molecule/default/playbooks). To run the test, you
need [`tox`](https://tox.wiki/en/latest/).

```sh
pip3 install --user tox
~/.local/bin/tox
```

The web interface is located at
[http://192.168.21.200:8010/](http://192.168.21.200:8010/).

# Requirements

None

# Role Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `buildbot_user` | user of `buildbot` | `buildbot` |
| `buildbot_group` | group of `buildbot` | `buildbot` |
| `buildbot_package` | package name of `buildbot` | `{{ __buildbot_package }}` |
| `buildbot_extra_packages` | list of additional packages to install | `{{ __buildbot_extra_packages }}` |
| `buildbot_extra_pip_packages` | list of additional pip packages to install | `[]` |
| `buildbot_service` | name of `buildbot` service | `{{ __buildbot_service }}` |
| `buildbot_root_dir` | path to root directory of `buildbot`, usually same as `buildbot_conf_dir` | `{{ __buildbot_root_dir }}` |
| `buildbot_conf_dir` | path to directory where configuration files are | `{{ buildbot_root_dir }}` |
| `buildbot_conf_file` | path to the configuration file | `{{ buildbot_conf_dir }}/master.cfg` |
| `buildbot_executable` | path to `buildbot` executable | `{{ __buildbot_executable }}` |
| `buildbot_master_cfg_content` content of the configuration file | | `""` |
| `buildbot_flags` | content of startup configuration file | `""` |
| `buildbot_create_master_executable` | path to command to run `create-master` | "{{ buildbot_executable }}"
| `buildbot_create_master_user` | user to run `create-master` | "{{ buildbot_user }}"
| `buildbot_create_master_flags` | command line flags to pass `buildbot create-master` command | `-r` |

## Debian

| Variable | Default |
|----------|---------|
| `__buildbot_package` | `python3-buildbot` |
| `__buildbot_extra_packages` | `[]` |
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
    - name: trombik.pip
    - ansible-role-buildbot
    - name: trombik.buildbot_worker
    - name: trombik.haproxy
  vars:
    project_worker_name: example-worker
    project_worker_password: pass
    project_backend_host: 127.0.0.1
    project_frontend_port: 8000
    project_backend_port: 8010
    project_user_admin: admin
    project_user_admin_password: password
    project_user_guest: guest
    project_user_guest_password: guest

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
      c['workers'] = [worker.Worker("{{ project_worker_name }}", "{{ project_worker_password }}")]
      c['protocols'] = {'pb': {'port': 9989}}
      c['change_source'] = []
      c['change_source'].append(changes.GitPoller(
              'git://github.com/buildbot/hello-world.git',
              workdir='gitpoller-workdir', branch='master',
              gitbin='git',
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
            workernames=["{{ project_worker_name }}"],
            factory=factory))
      c['services'] = []
      c['title'] = "Hello World CI"
      c['titleURL'] = "https://buildbot.github.io/hello-world/"
      c['buildbotURL'] = "http://localhost:{{ project_frontend_port }}/"
      c['www'] = dict(port={{ project_backend_port }},
                      plugins=dict(waterfall_view={}, console_view={}, grid_view={}))
      c['db'] = {
          'db_url' : "sqlite:///state.sqlite",
      }

    os_buildbot_extra_packages:
      FreeBSD:
        - devel/py-buildbot-www
      RedHat:
        - python36-pip
        - python36-devel
        - openssl-devel
      Debian:
        - python3-pip

    buildbot_extra_packages: "{{ os_buildbot_extra_packages[ansible_os_family] | default([]) }}"
    os_buildbot_extra_pip_packages:
      Debian:
        - buildbot-www
        - buildbot-waterfall-view
        - buildbot-console-view
        - buildbot-grid-view
    buildbot_extra_pip_packages: "{{ os_buildbot_extra_pip_packages[ansible_os_family] | default([]) }}"

    # ________________________________________________buildbot_worker
    os_buildbot_worker_flags:
      FreeBSD: |
        buildbot_worker_basedir="{{ buildbot_worker_conf_dir }}"
      # "
      Debian: |
        #WORKER_RUNNER=/usr/bin/buildbot-worker

        # 'true|yes|1' values in WORKER_ENABLED to enable instance and 'false|no|0' to
        # disable. Other values will be considered as syntax error.

        WORKER_ENABLED[1]=1                    # 1-enabled, 0-disabled
        WORKER_NAME[1]="default"               # short name printed on start/stop
        WORKER_USER[1]="buildbot"              # user to run worker as
        WORKER_BASEDIR[1]="{{ buildbot_worker_conf_dir }}"  # basedir to worker (absolute path)
        WORKER_OPTIONS[1]=""                   # buildbot options
        WORKER_PREFIXCMD[1]=""                 # prefix command, i.e. nice, linux32, dchroot
    # "

    buildbot_worker_flags: "{{ os_buildbot_worker_flags[ansible_os_family] | default('') }}"
    buildbot_worker_config: |
      import os
      from buildbot_worker.bot import Worker
      from twisted.application import service
      basedir = '{{ buildbot_worker_conf_dir }}'
      rotateLength = 10000000
      maxRotatedFiles = 10
      # if this is a relocatable tac file, get the directory containing the TAC
      if basedir == '.':
          import os.path
          basedir = os.path.abspath(os.path.dirname(__file__))
      # note: this line is matched against to check that this is a worker
      # directory; do not edit it.
      application = service.Application('buildbot-worker')
      from twisted.python.logfile import LogFile
      from twisted.python.log import ILogObserver, FileLogObserver
      logfile = LogFile.fromFullPath(
          os.path.join(basedir, "twistd.log"), rotateLength=rotateLength,
          maxRotatedFiles=maxRotatedFiles)
      application.setComponent(ILogObserver, FileLogObserver(logfile).emit)
      buildmaster_host = 'localhost'
      port = 9989
      workername = '{{ project_worker_name }}'
      passwd = '{{ project_worker_password }}'
      keepalive = 600
      umask = None
      maxdelay = 300
      numcpus = None
      allow_shutdown = None
      maxretries = None
      s = Worker(buildmaster_host, port, workername, passwd, basedir,
                 keepalive, umask=umask, maxdelay=maxdelay,
                 numcpus=numcpus, allow_shutdown=allow_shutdown,
                 maxRetries=maxretries)
      s.setServiceParent(application)

    # _______________________________________freebsd_pkg_repo
    # use my own packages because ones in ports have been broken.
    freebsd_pkg_repo:
      FreeBSD:
        enabled: "false"
        state: present
      # enable my own package repository, where the latest package is
      # available
      FreeBSD_devel:
        enabled: "true"
        state: present
        url: "http://pkg.i.trombik.org/{{ ansible_distribution_version | regex_replace('\\.', '') }}{{ansible_architecture}}-default-default/"
        mirror_type: http
        signature_type: none
        priority: 100

    # _______________________________________redhat_repo
    redhat_repo:
      epel:
        mirrorlist: "http://mirrors.fedoraproject.org/mirrorlist?repo=epel-{{ ansible_distribution_major_version }}&arch={{ ansible_architecture }}"
        gpgcheck: yes
        enabled: yes
        description: EPEL

    # _______________________________________haproxy
    os_haproxy_selinux_seport:
      FreeBSD: {}
      Debian: {}
      RedHat:
        ports:
          - "{{ project_frontend_port }}"
          - 8404
        proto: tcp
        setype: http_port_t
    haproxy_selinux_seport: "{{ os_haproxy_selinux_seport[ansible_os_family] }}"
    haproxy_config: |
      global
        daemon
      {% if ansible_os_family == 'FreeBSD' %}
      # FreeBSD package does not provide default
        maxconn 4096
        log /var/run/log local0 notice
          user {{ haproxy_user }}
          group {{ haproxy_group }}
      {% elif ansible_os_family == 'Debian' %}
        log /dev/log  local0
        log /dev/log  local1 notice
        chroot {{ haproxy_chroot_dir }}
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user {{ haproxy_user }}
        group {{ haproxy_group }}

        # Default SSL material locations
        ca-base /etc/ssl/certs
        crt-base /etc/ssl/private

        # See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
          ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
          ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
          ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets
      {% elif ansible_os_family == 'OpenBSD' %}
        log 127.0.0.1   local0 debug
        maxconn 1024
        chroot {{ haproxy_chroot_dir }}
        uid 604
        gid 604
        pidfile /var/run/haproxy.pid
      {% elif ansible_os_family == 'RedHat' %}
      log         127.0.0.1 local2
      chroot      /var/lib/haproxy
      pidfile     /var/run/haproxy.pid
      maxconn     4000
      user        haproxy
      group       haproxy
      daemon
      {% endif %}

      defaults
        log global
        mode http
        timeout connect 5s
        timeout client 10s
        timeout server 10s
        option  httplog
        option  dontlognull
        retries 3
        maxconn 2000
      {% if ansible_os_family == 'Debian' %}
        errorfile 400 /etc/haproxy/errors/400.http
        errorfile 403 /etc/haproxy/errors/403.http
        errorfile 408 /etc/haproxy/errors/408.http
        errorfile 500 /etc/haproxy/errors/500.http
        errorfile 502 /etc/haproxy/errors/502.http
        errorfile 503 /etc/haproxy/errors/503.http
        errorfile 504 /etc/haproxy/errors/504.http
      {% elif ansible_os_family == 'OpenBSD' %}
        option  redispatch
      {% endif %}

      frontend http-in
        bind *:{{ project_frontend_port }}
        acl auth_ok http_auth(my_users)
        http-request auth unless auth_ok
        default_backend servers

      userlist my_users
        user {{ project_user_admin }} insecure-password {{ project_user_admin_password }}
        user {{ project_user_guest }} insecure-password {{ project_user_guest_password }}

      backend servers
        option forwardfor
        server server1 {{ project_backend_host }}:{{ project_backend_port }} maxconn 32 check

      frontend stats
        bind *:8404
        mode http
        no log
        acl network_allowed src 127.0.0.0/8
        tcp-request connection reject if !network_allowed
        stats enable
        stats uri /
        stats refresh 10s
        stats admin if LOCALHOST

    os_haproxy_flags:
      FreeBSD: |
        haproxy_config="{{ haproxy_conf_file }}"
        #haproxy_flags="-q -f ${haproxy_config} -p ${pidfile}"
      Debian: |
        #CONFIG="/etc/haproxy/haproxy.cfg"
        #EXTRAOPTS="-de -m 16"
      OpenBSD: ""
      RedHat: |
        OPTIONS=""
    haproxy_flags: "{{ os_haproxy_flags[ansible_os_family] }}"
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
