#!/usr/bin/env bash

export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:.

logfile="/var/automata/logs/puppet-run.log"
proxyrc=~/.automata_rc
dir="$(dirname $(readlink -f $0))"
pwdir=$(pwd)
r10k_bin=$(which r10k)
puppet_bin=$(which puppet)
git_bin=$(which git)

source ${dir}/functions

[[ -f $proxyrc ]] && source $proxyrc 
proxy=${xproxy}
noproxy=${nproxy}
VERBOSE=${verbose}
moduledir_name=$(get_module_path)
moduledir=${moduledir_name:-'site'}
branch_name=$(get_branch_name)
branch=${branch_name:-'master'}

trap cleanup EXIT
trap sig_cleanup INT QUIT TERM
 
usageAndExit() {
  rec=$1
  [[ -n "$rec" ]] && echo $rec >&2
  echo "${PROGNAME} [-p |--proxy <proxy-url>] [-n|--noproxy] [-h|--help] [-v|--verbose]" >&2
  exit 1
}

for arg in "$@"; do
  shift
    case "$arg" in
       "--help")    set -- "$@" "-h" ;;
       "--verbose") set -- "$@" "-v" ;;
       "--proxy")   set -- "$@" "-p" ;;
       "--noproxy") set -- "$@" "-n" ;;
       *)           set -- "$@" "$arg";;
    esac
done

OPTIND=1
while getopts ":p:n:vh" opt; do
  case $opt in
     h) usageAndExit;;
     p) proxy=$OPTARG;;
     v) VERBOSE='--verbose';;
     n) noproxy='1';;
     *) usageAndExit;;
  esac
done
shift $((OPTIND-1))

pushd ${dir}/.. >/dev/null 2>&1

setproxy
( [[ ! -n $noproxy ]] && [[ -n $proxy ]] ) && source .profile.$$ 2>/dev/null

i=1
while [[ $i -gt 0 ]]; do
	$git_bin pull origin ${branch} >${logfile} 2>&1 && ${r10k_bin} puppetfile install --moduledir=${moduledir} ${VERBOSE} >>${logfile} 2>&1
if [[ -n $(egrep -i "(could not resolve proxy|failed to connect)" ${logfile}) ]]; then
   unsetproxy
   source .profile.$$ 2>/dev/null 
   $git_bin pull origin ${branch} >>${logfile} 2>&1 && ${r10k_bin} puppetfile install --moduledir=${moduledir} ${VERBOSE} >>${logfile} 2>&1
   i=$(( i-1 ))
else 
   i=-1
fi	
done

warnings=$(grep -i "skipping" ${logfile} |sed 's/.*Skipping *\([a-zA-Z0-9\/]*\) .*/\1/g')

if [[ -n ${warnings} ]]; then
   for x in $(echo $warnings); do
	rm -rf "${x}" >>${logfile} 2>&1
   done
   $r10k_bin puppetfile install --moduledir=${moduledir} ${VERBOSE} >>${logfile} 2>&1 && $puppet_bin apply --modulepath=modules:${moduledir}:'$basemodulepath' manifests/site.pp ${VERBOSE} >>${logfile} 2>&1
else
   $puppet_bin apply --modulepath=modules:${moduledir}:'$basemodulepath' manifests/site.pp ${VERBOSE} >>${logfile} 2>&1
fi

if [[ -f $logfile ]]; then
  output_log=$(echo $logfile |sed 's/\(.*\)\(\.log.*\)/\1\.out\2/')
  echo -e "\n[$(date)]" >> ${output_log}
  cat "${logfile}" >> ${output_log}
fi

cd ${pwdir}
