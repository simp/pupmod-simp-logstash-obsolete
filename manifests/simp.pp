# == Class: logstash::simp
#
# This class extends the electrical-logstash module in the configuration
# settings recommended for SIMP systems.
#
# This allows for connecting to an ES system that is running behind
# HTTPS using stunnel.
#
# It also allows you to encrypt traffic to the LogStash log collector just like
# our rsyslog remote configuration.
#
# We also muck about with some IPTables NAT rules so that LogStash can run as a
# normal user while collecting syslog traffic from other hosts.
#
# This is currently configured as a catch-all type of system. There is no
# output filtering. If you need logstash filters or additional inputs/outputs,
# you will need to configure them yourself.
#
# This class expects that you have setup and configured stunnel. This will
# happen by default if you're using a SIMP installation.
#
# NOTE: This class is incompatible with the SIMP rsyslog::stock::server class!
#
# See logstash::simp::clean if you want to automatically prune your
# logs to conserve ElasticSearch storage space.
#
# == Parameters
#
# [*client_nets*]
#   Type: Array
#   An array of networks that you trust to connect to your server.
#
# [*listen_plain_tcp*]
#  Boolean:
#    Whether or not to listen on the default unencrypted TCP syslog port.
#  Default: true
#
# [*listen_plain_udp*]
#  Boolean:
#    Whether or not to listen on the default unencrypted UDP syslog port.
#  Default: true
#
# [*es_host*]
#   IP or FQDN:
#     The IP or FQDN of the ES server to which this LogStash collector should
#     send. This will, most likely, be on the local host.
#   Default: 127.0.0.1
#
# [*es_port*]
#   Integer:
#     The port number to which to connect on the ES server.
#   Default: 9200
#
# [*stunnel_elasticsearch*]
#   Boolean:
#     Whether or not to use a stunnel connection to connect to ES. This is
#     necessary if you are using ES behind an HTTPS proxy.
#     If you're using ES on the same host, and using the elasticsearch::simp
#     class (the default), then the system will auto-adjust to ignore this
#     setting.
#   Default: True
#
# [*stunnel_syslog_input*]
#   Boolean:
#     Whether or not to set up a stunnel connection on port 5140 for allowing
#     clients to send logs to the server over an encrypted channel. The usual
#     514 port will also listen for connections on both TCP and UDP for devices
#     which simply do not support encrypted connections.
#   Default: true
#
# [*auto_clean*]
#   Boolean:
#     If true, will include the elasticsearch-curator utility to purge
#     ElasticSearch entries beyond a certain date. You will need to
#     set the appropriate variables in Hiera for
#     logstash::simp::clean for this to be maximally
#     effective.
#   Default: true
#
# [*auto_optimize*]
#   Boolean:
#     If true, will include the elasticsearch-curator utility to
#     optimize ElasticSearch entries beyond a certain date. You will
#     need to set the appropriate variables in Hiera for
#     logstash::simp::clean for this to be maximally effective.
#   Default: true
#
# [*keep_days*]
#   Integer:
#     If set, will automatically set up a cron job to expire your logs from ES
#     after a certain number of days. This will probably only work if you have
#     ES on the same host as LogStash. If you have any doubts, don't set this
#     and just call logstash::simp::index_cleanup directly.
#
#     * To delete the cron job, set to '0' *
#
#   Default: ''
#
# [*manage_sysctl*]
#   Boolean:
#     If set, this class will manage the following sysctl variables.
#     * net.ipv4.conf.all.route_localhost
#   Default: true
#
# == Authors
#
# * Trevor Vaughan <tvaughan@onyxpoint.com>
#
class logstash::simp (
  $client_nets           = hiera('client_nets','127.0.0.1'),
  $listen_plain_tcp      = false,
  $listen_plain_udp      = false,
  $auto_clean            = true,
  $auto_optimize         = true,
  $es_host               = '127.0.0.1',
  $es_port               = '9200',
  $stunnel_elasticsearch = true,
  $stunnel_syslog_input  = true,
  $manage_sysctl         = true
) {
  include 'logstash'

  $es_is_local = ($es_host == '127.0.0.1')

  if $auto_clean { include 'logstash::simp::clean' }
  else { cron { 'logstash_index_cleanup': ensure => 'absent' } }
  if $auto_optimize { include 'logstash::simp::optimize' }
  else { cron { 'logstash_index_optimize': ensure => 'absent' } }

  if $listen_plain_tcp or $listen_plain_udp {
    # IPTables rules so that LogStash doesn't have to run as root.
    iptables_rule { 'syslog_redirect':
      table    => 'nat',
      absolute => true,
      first    => true,
      order    => '1',
      header   => false,
      content  => '
  -A PREROUTING -p tcp -m tcp --dport 514 -j DNAT --to-destination 127.0.0.1:51400
  -A PREROUTING -p udp -m udp --dport 514 -j DNAT --to-destination 127.0.0.1:51400',
      require  => Logstash::Input::Syslog['default_syslog']
    }

    if $manage_sysctl {
      include 'sysctl'

      # Allow the iptables NAT rules to work properly.
      sysctl::value { 'net.ipv4.conf.all.route_localnet': value => '1' }
    }
  }


  if $listen_plain_tcp {
    iptables::add_tcp_stateful_listen { 'syslog_tcp':
      client_nets => $client_nets,
      dports      => '514'
    }
    iptables_rule { 'syslog_tcp_nat_allow':
      content => '-d 127.0.0.1 -p tcp -m tcp -m multiport --dports 51400 -j ACCEPT'
    }
  }
  if $listen_plain_udp {
    iptables::add_udp_listen { 'syslog_udp':
      client_nets => $client_nets,
      dports      => '514'
    }
    iptables_rule { 'syslog_udp_nat_allow':
      content => '-d 127.0.0.1 -p udp -m udp -m multiport --dports 51400 -j ACCEPT'
    }
  }

  # LogStash Syslog Input
  logstash::input::syslog { 'default_syslog':
    type => 'syslog',
    host => '127.0.0.1',
    port => '51400'
  }

  if $stunnel_elasticsearch {
    include 'stunnel'

    if ! $es_is_local {
      stunnel::add { 'logstash_elasticsearch':
        client  => true,
        connect => ["${es_host}:${es_port}"],
        accept  => '127.0.0.1:9200'
      }
    }

    logstash::output::elasticsearch_http { 'elasticsearch_default':
      host    => '127.0.0.1',
      port    => $es_is_local ? {
        true    => '9199',
        default => '9200'
      },
      require => $es_is_local ? {
        # Ok, this is sort of stupid, but I don't have a more elegant way of
        # doing it.
        true    => Package['logstash'],
        default => Stunnel::Stunnel_add['logstash_elasticsearch']
      }
    }
  }
  else {
    logstash::output::elasticsearch_http { 'elasticsearch_default':
      host => $es_host,
      port => $es_port
    }
  }

  if $stunnel_syslog_input {
    include 'stunnel'
    include 'tcpwrappers'

    stunnel::add { 'logstash_syslog':
      client  => false,
      connect => ['51400'],
      accept  => '5140'
    }

    # This handles traditional syslog-tls input.
    stunnel::add { 'logstash_syslog_tls':
      client  => false,
      connect => ['51400'],
      accept  => '6514'
    }

    tcpwrappers::allow { ['logstash_syslog','logstash_syslog_tls']:
      pattern => 'ALL'
    }
  }

  # This isn't necessarily the best place for this
  package { 'elasticsearch-curator': ensure => 'latest' }

  validate_net_list($client_nets)
  validate_bool($listen_plain_tcp)
  validate_bool($listen_plain_udp)
  validate_bool($auto_clean)
  validate_integer($es_port)
  validate_bool($stunnel_elasticsearch)
  validate_bool($stunnel_syslog_input)
}
