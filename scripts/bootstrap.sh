#!/usr/bin/env bash
PROGNAME=$(basename $0)

cwd=$(pwd)
dir="$(dirname $(readlink -f $0))"
r10k_bin="$(which r10k)"
puppet_bin="$(which puppet)"
git_bin="$(which git)"

usageAndExit() {
  rec=$1
  [[ -n "$rec" ]] && echo $rec >&2
  echo "${PROGNAME} -e <environment> [-a <application> | -p <productname>] [-h]" >&2
  exit 1
}

facts_setter() {

dirs=$(cat <<'EOF'
/opt/puppetlabs/facter
/etc/puppetlabs/facter
/etc/puppet/facter
/etc/facter
EOF
)

FY=$(cat <<EOT
---
product_environment: $environment
product_name: $productname
EOT
)

_excode=1
for fdir in $(echo "$dirs"); do
  if [[ -d ${fdir} ]]; then
    echo "Found ${fdir}..." >&2
    if [[ -d "${fdir}/facts.d" ]]; then
      echo "Creating facts..." >&2
    else
      echo "Creating facts.d..." >&2
      mkdir -p ${fdir}/facts.d 2>/dev/null
      _excode=$?
      if [[ $_excode -gt 0 ]]; then
        echo "Unable to create facts.d..." >&2
	continue
      fi
    fi
    echo "${FY}" > ${fdir}/facts.d/bnsgwms_masterless.yaml 2>/dev/null
    _excode=$?
    if [[ $_excode -gt 0 ]]; then
      echo "Failed to create facts..." >&2
      continue
    fi
    break
  fi
done

return $_excode
}

while getopts ":p:a:e:vh" opt; do
  case $opt in
	h)   usageAndExit;;
	e)   prov_environment=$OPTARG;;
        p|a) productname=$OPTARG;;
        v)   VERBOSE='--verbose';;
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
  echo "${environment}" > /etc/.host.product.env 2>/dev/null
  vcode=$?
  echo "${productname}" > /etc/.host.product.name 2>/dev/null
  ncode=$?

  ( [[ $xcode -gt 0 ]] || [[ $vcode -gt 0 ]] || [[ $ncode -gt 0 ]] ) && echo "One or more errors encountered" >&2 && exit 1
fi

pushd $dir/.. >/dev/null
$r10k_bin puppetfile install ${VERBOSE}

$puppet_bin apply manifests/site.pp ${VERBOSE}
