#!/usr/bin/env bash
PROGNAME=$(basename $0)
dir="$(dirname $(readlink -f $0))"
r10k_bin="$(which r10k)"
puppet_bin="$(which puppet)"
git_bin="$(which git)"
environment=''
productname=''
user=$(whoami)
offline=false
bnsautomata_log=/tmp/.${PROGNAME}.log

source ${dir}/functions

usageAndExit() {
  echo "${PROGNAME} [-e <environment>] [-a|--appenv <app_environment>] [-p <productname>] [-x|--proxy <url>] [-n|--noproxy] [-h|--help] [-v|--verbose] [-d|--debug] [-o|--offline]" >&2
  exit 1
}

# Check if we are using root permissions and if sudo is available
if [ "$user" != "root" ] &&  ! sudo -h > /dev/null 2>&1; then
  echo "This script needs to be run as root or sudo needs to be installed on the machine"
  exit 1
fi

rm -f ~/.automata_rc 2>/dev/null

for arg in "$@"; do
  shift
  case "$arg" in
    "--help")    set -- "$@" "-h" ;;
    "--offline") set -- "$@" "-o" ;;
    "--appenv")  set -- "$@" "-a" ;;
    "--verbose") set -- "$@" "-v" ;;
    "--debug")   set -- "$@" "-d" ;;
    "--proxy")   set -- "$@" "-x" ;;
    "--noproxy") set -- "$@" "-n" ;;
    *)           set -- "$@" "$arg";;
  esac
done

OPTIND=1
while getopts ":p:a:e:x:dvho" opt; do
  case $opt in
	h) usageAndExit;;
	e) prov_environment=$OPTARG;;
	p) productname=$OPTARG;;
	a) app_env="-a $OPTARG";;
	x) proxy="$OPTARG"; echo "export xproxy=$proxy" >> ~/.automata_rc;;
	n) noproxy="1"; echo "export nproxy=1" >> ~/.automata_rc;;
	o) offline=true;;
	v) VERBOSE='-v';;
	d) DEBUG='-d';;
	*) usageAndExit;;
  esac
done
shift $((OPTIND-1))

if [[ -n $prov_environment ]]; then
  case "$prov_environment" in 
    'dev')          environment='development';;
    'ist')          environment='ist';;
    'qat'|'uat')    environment='uat';;
    'nft'|preprod*) environment='preproduction';;
    prod*)          environment='production';;
    *)              environment=${prov_environment};;
  esac
fi

if [[ ! -n $git_bin ]]; then
  install_git
fi

if [[ ! -n $environment ]] || [[ ! -n $productname ]]; then
  # Node environment and product name is required
  usageAndExit "missing required param/value"
fi

if [[ ! -n $puppet_bin ]]; then
  _prompt puppet
  ans=$?
  ( [[ ! -n $ans ]] || [[ $ans -gt 0 ]] ) && exit 1
  install_puppet $(osvers) 2>&1
  exit
fi

if [[ ! -n $r10k_bin ]]; then
  _prompt r10k 
  ans=$?
  ( [[ ! -n $ans ]] || [[ $ans -gt 0 ]] ) && exit 1
  install_r10k $(osvers) 2>&1
  exit
fi

if [[ $offline != true ]]; then
  check_repo_branch "${environment}"
fi

${dir}/bootstrap.sh -e "${environment}" -p "${productname}" ${app_env} ${VERBOSE} ${DEBUG}

