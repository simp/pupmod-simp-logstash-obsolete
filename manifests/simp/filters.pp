# == Class: logstash::simp::filters
#
# This class extends the simp logstash module and adds
# some custom logstash filters
#
# This will force the logs to be parsed into more usable formats.
#
# == Parameters
#
# == Authors
#
# * Ralph Wright <rwright@onyxpoint.com>
# * Trevor Vaughan <tvaughan@onyxpoint.com>
#
class logstash::simp::filters {
  file {'/etc/logstash/conf.d/simp_filters':
    ensure => file,
    owner  => 'logstash',
    group  => 'logstash',
    mode   => '0600',
    source  => 'puppet:///modules/logstash/simp_filters',
    notify => Service['logstash'],
  }

  file {'/opt/logstash/patterns/audit':
    ensure => file,
    owner  => 'logstash',
    group  => 'logstash',
    mode   => '0600',
    source  => 'puppet:///modules/logstash/audit',
    notify => Service['logstash'],
  }
}
