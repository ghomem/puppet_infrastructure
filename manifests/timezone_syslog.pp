### Purpose ########
#   configure the timezone of the node and
#   configure rsyslog to write the timestamps in the timezone but with UTC delta
### Warnings #######
# If the hiera configuration below is absent, any existing logging configuration (including OS defaults) may be lost!
### Inputs #########
# The hiera configuration should have these entries to avoid loosing existing logging configurations:
# rsyslog::purge_config_files: false
# rsyslog::override_default_config: false
# rsyslog::target_file: '00_rsyslog.conf'
# rsyslog::server::global_config:
#   ActionFileDefaultTemplate:
#     value: 'RSYSLOG_FileFormat'
#     type: legacy
### Dependencies ###
# Required puppet forge modules:
# - saz-timezone (tested with: v4.1.1)
# - puppet-rsyslog (tested with: v2.3.0)
### References #####
#   JIRA issue MANUT-543

class puppet_infrastructure::timezone_syslog (
  # desired timezone (to list them on ubuntu 16.04, run 'timedatectl list-timezones')
  # special case UTC needs to be written Etc/UTC
  String $tz = 'Etc/UTC',
){

  class { 'timezone':
    timezone => $tz,
  }

  # we need the rsyslog::server because that's the onde that "Configures template objects in rsyslog"
  # (rsyslog::client does not have that)
  class { 'rsyslog::server':
  }

}
