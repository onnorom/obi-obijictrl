#!/usr/bin/env bash
PROGNAME=$(basename $0)
cwd=$(pwd)
dir="$(dirname $(readlink -f $0))"
r10k_bin="$(which r10k)"
puppet_bin="$(which puppet)"
git_bin="$(which git)"
rootdir='/etc'
cache=${dir}/.cache

source ${dir}/functions

trap cleanup EXIT
trap sig_cleanup INT QUIT TERM

usageAndExit() {
  rec=$1
  [[ -n "$rec" ]] && echo $rec >&2
  echo "${PROGNAME} -e <environment> [-a <app_environment>] [-p <productname>] [-h|--help] [-v|--verbose] [-d|--debug]" >&2
  exit 1
}

while getopts ":p:a:e:dvh" opt; do
  case $opt in
	h)   usageAndExit;;
	e)   prov_environment=$OPTARG;;
        p)   productname=$OPTARG;;
        a)   app_environment=$OPTARG;;
        v)   VERBOSE='--verbose'; touch ${dir}/.verbose;;
        d)   DEBUG='--debug';;
	*)   usageAndExit;;
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

if [[ ! -n $environment ]] || [[ ! -n $productname ]]; then
  # Node environment based and product name is required
  usageAndExit "missing required param/value"
else
  if [[ ! -n $puppet_bin ]] || [[ ! -n $r10k_bin ]] || [[ ! -n $git_bin ]]; then
    echo "Machine appear to be missing puppet, git and/or r10k. Please run ${dir}/setup.sh..." >&2 
    exit 1
  fi

  facts_setter
  xcode=$?
  echo "${environment}" > ${rootdir}/.host.product.env 2>/dev/null
  vcode=$?
  echo "${productname}" > ${rootdir}/.host.product.name 2>/dev/null
  ncode=$?

  ( [[ $xcode -gt 0 ]] || [[ $vcode -gt 0 ]] || [[ $ncode -gt 0 ]] ) && echo "One or more facts setup errors encountered" >&2 && exit 1
  echo "${dir}" > ${rootdir}/.host.control.dir 2>/dev/null

  [[ -n $app_environment ]] && echo "${app_environment}" > ${rootdir}/.host.app.env 2>/dev/null
  mkdir -p $cache && touch ${cache}/locks
fi

moduledirname=$(get_module_path)
moduledir=${moduledirname:-'site'}
pushd $dir/.. >/dev/null 2>&1
$r10k_bin puppetfile install --moduledir=${moduledir} ${VERBOSE} 2>&1 |tee -a /tmp/.${PROGNAME}.log

$puppet_bin apply --modulepath=modules:${moduledir}:'$basemodulepath' manifests/site.pp ${VERBOSE} ${DEBUG} 2>&1 |tee -a /tmp/.${PROGNAME}.log

