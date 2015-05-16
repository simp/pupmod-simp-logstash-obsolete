# == Class : logstash::simp::clean
#
# This class sets up a cron job to clean your ElasticSearch indices on a
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
# [*keep_days*]
#   Integer:
#     The number of days to keep within ElasticSearch.
#     Mutually exclusive with keep_hours and keep_space.
#   Default: 356
#
# [*keep_hours*]
#   Integer:
#     The number of hours to keep within ElasticSearch.
#     Mutually exclusive with keep_days and keep_space.
#
# [*keep_space*]
#   Integer:
#     The number of Gigabytes to keep within ElasticSearch.
#     This applies to each index individually, not the entire storage space
#     used by the prefix.
#     Mutually exclusive with keep_days and keep_hours.
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
#   Default: '30'
#
# [*log_file*]
#   Absolute Path
#     The log file to which to print curator output.
# Default: '/var/log/logstash/curator.log'
#
# [*cron_hour*]
#   Integer or '*':
#     The hour at which to run the index cleanup.
#   Default: '1'
#
# [*cron_minute*]
#   Integer or '*':
#     The minute at which to run the index cleanup.
#   Default: '13'
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
class logstash::simp::clean (
  $ensure = 'present',
  $host = '127.0.0.1',
  $keep_days = '356',
  $keep_hours = '',
  $keep_space = '',
  $prefix = 'logstash-',
  $port = '9199',
  $separator = '.',
  $es_timeout = '30',
  $log_file = '/var/log/logstash/curator_clean.log',
  $cron_hour = '1',
  $cron_minute = '15',
  $cron_month = '*',
  $cron_monthday = '*',
  $cron_weekday = '*'
) {

  if size(reject([$keep_days, $keep_hours, $keep_space],'^\s*$')) > 1 {
    fail('You may only specify one of $keep_days, $keep_hours, or $keep_space')
  }

  if ! empty($keep_hours) {
    validate_integer($keep_hours)
    $l_limit = "-T hours --older-than ${keep_hours}"
  }
  elsif ! empty($keep_days) {
    validate_integer($keep_days)
    $l_limit = "-T days --older-than ${keep_days}"
  }
  elsif ! empty($keep_space) {
    validate_integer($keep_space)
    $l_limit = "--disk-space ${keep_space}"
  }
  else {
    fail('You must specify one of $keep_days, $keep_hours, or $keep_space')
  }

  cron { 'logstash_index_cleanup' :
    ensure   => $ensure,
    command  => "/usr/bin/curator --host ${host} --port ${port} -t ${es_timeout} delete -p '${prefix}' -s '${separator}' ${l_limit} >> ${log_file} 2>&1",
    hour     => $cron_hour,
    minute   => $cron_minute,
    month    => $cron_month,
    monthday => $cron_monthday,
    weekday  => $cron_weekday,
    require  => Package['elasticsearch-curator']
  }

  validate_integer($port)
  validate_integer($es_timeout)
  validate_absolute_path($log_file)
  validate_integer($cron_hour)
  validate_integer($cron_minute)
}
