#!/usr/bin/env bash
service_status="/usr/sbin/service obijiautomata-production status"

#service { 'obijiautomata-production':
#  ensure    => stopped,
#  enable    => false,
#  hasstatus => true,
#  #status    => "/etc/automata/bin/obijiautomata-status-check.sh",
#}->file { '/etc/systemd/system/obijiautomata-production.service':
#     ensure => absent,
#}

$service_status >/dev/null 2>&1
exitcode=$?
if [[ $exitcode = 0 ]]; then
  exit 0 
else
  if [[ -f /etc/systemd/system/obijiautomata-production.service ]]; then 
    # exit 1 -- to bring it up if ensure=running or leave in current state if ensure=stopped 
    # exit 0 -- to leave it as is if ensure=stopped (down) or bring up if ensure=running
    exit 1
  else 
    # service is neither installed nor running 
    # exit 1 or 0 -- leaves in current state if ensure=stopped and enable=false
    # exit 0 or 1 -- will error out if ensure=running as service does not exist
    exit 1  
  fi
fi
