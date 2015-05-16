# == Class: logstash::simp::optimize
#
# This class sets up a cron job to optimize your ElasticSearch indices on a
# regular basis using elasticsearch-curator.
#
# == Parameters
#
# [*ensure*]
#   String: 'present' | 'absent'
#     Whether to add, or delete, the index job.
#   Default: 'present'
#
# [*host*]
#   FQDN or IP:
#     The host upon which to operate. Ideally, you will position this job
#     locally but it will work over thet network just as well provided your
#     access controls allow it.
#   Default: 127.0.0.1
#
# [*optimize_days*]
#   Integer:
#     The number of days to keep within ElasticSearch.
#     Mutually exclusive with optimize_hours.
#   Default: '2'
#
# [*optimize_hours*]
#   Integer:
#     The number of hours to keep within ElasticSearch.
#     Mutually exclusive with optimize_days.
#
# [*prefix*]
#   String:
#     The prefix to use to identify relevant logs.
#     This is a match so 'foo' will match 'foo', 'foosball', and 'foot'.
#   Default: 'logstash-'
#
# [*port*]
#   Integer:
#     The port to which to connect. Since this is SIMP tailored, we use our
#     local unencrypted default.
#   Default: 9199
#
# [*separator*]
#   Character:
#     The index separator.
#   Default: '.'
#
# [*es_timeout*]
#   Integer:
#     The timeout, in seconds, to wait for a response from
#     Elasticsearch.
#   Default: '21600'
#
# [*max_num_segments*]
#   Integer:
#     Optimize segment count to $max_num_segments per shard.
#   Default: '2'
#
# [*log_file*]
#   Absolute Path
#     The log file to which to print curator output.
# Default: '/var/log/logstash/curator_optimize.log'
#
# [*cron_hour*]
#   Integer or '*':
#     The hour at which to run the index cleanup.
#   Default: '3'
#
# [*cron_minute*]
#   Integer or '*':
#     The minute at which to run the index cleanup.
#   Default: '30'
#
# [*cron_month*]
#   Integer or '*':
#     The month within which to run the index cleanup.
#   Default: '*'
#
# [*cron_monthday*]
#   Integer or '*':
#     The day of the month upon which to run the index cleanup.
# Default: '*'
#
# [*cron_weekday*]
#   Integer or '*':
#     The day of the week upon which to run the index cleanup.
# Default: '*'
#
class logstash::simp::optimize (
  $ensure = 'present',
  $host = '127.0.0.1',
  $optimize_days = '2',
  $optimize_hours = '',
  $prefix = 'logstash-',
  $port = '9199',
  $separator = '.',
  $es_timeout = '21600',
  $max_num_segments = '2',
  $log_file = '/var/log/logstash/curator_optimize.log',
  $cron_hour = '3',
  $cron_minute = '15',
  $cron_month = '*',
  $cron_monthday = '*',
  $cron_weekday = '*'
) {

  if size(reject([$optimize_days, $optimize_hours],'^\s*$')) > 1 {
    fail('You may only specify one of $optimize_days or $optimize_hours')
  }

  if ! empty($optimize_hours) {
    validate_integer($optimize_hours)
    $l_limit = "-T hours --older-than ${optimize_hours}"
  }
  elsif ! empty($optimize_days) {
    validate_integer($optimize_days)
    $l_limit = "-T days --older-than ${optimize_days}"
  }
  else {
    fail('You must specify one of $optimize_days or $optimize_hours')
  }

  cron { 'logstash_index_optimize':
    ensure   => $ensure,
    command  => "/usr/bin/curator --host ${host} --port ${port} -t ${es_timeout} optimize -p '${prefix}' -s '${separator}' ${l_limit} --max_num_segments ${max_num_segments} >> ${log_file} 2>&1",
    hour     => $cron_hour,
    minute   => $cron_minute,
    month    => $cron_month,
    monthday => $cron_monthday,
    weekday  => $cron_weekday,
    require  => Package['elasticsearch-curator']
  }

  validate_integer($port)
  validate_integer($max_num_segments)
  validate_integer($es_timeout)
  validate_absolute_path($log_file)
  validate_integer($cron_hour)
  validate_integer($cron_minute)
}
