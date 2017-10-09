#!/usr/bin/env bash
logfile="/var/automata/logs/puppet-run.log"
dir="$(dirname $(readlink -f $0))"
pwdir=$(pwd)
r10k_bin=$(which r10k)
puppet_bin=$(which puppet)
git_bin=$(which git)
proxy='http://proxyprd.scotia-capital.com:8080'

. ${dir}/functions

moduledir_name=$(get_module_path)
moduledir=${moduledir_name:-'site'}
branch_name=$(get_branch_name)
branch=${branch_name:-'master'}

cleanup() {
    err=$?
    rm .profile.$$ 2>/dev/null 
    trap '' EXIT INT TERM
    exit $err 
}

sig_cleanup() {
    trap '' EXIT
    false
    cleanup
}

trap cleanup EXIT
trap sig_cleanup INT QUIT TERM

setproxy() {
   choice=$1
   case "$choice" in 
     yes|Yes)
        echo "export HTTP_PROXY=${proxy}" > .profile.$$
        echo "export HTTPS_PROXY=${proxy}" >> .profile.$$
        echo "export http_proxy=${proxy}" >> .profile.$$
        echo "export https_proxy=${proxy}" >> .profile.$$
	;;
     no|No)
   	echo "export HTTP_PROXY=" > .profile.$$
   	echo "export HTTPS_PROXY=" >> .profile.$$
   	echo "export http_proxy=" >> .profile.$$
   	echo "export https_proxy=" >> .profile.$$
	;;
     default)
         echo "export HTTP_PROXY=${proxy}" > .profile.$$
         echo "export HTTPS_PROXY=${proxy}" >> .profile.$$
         echo "export http_proxy=${proxy}" >> .profile.$$
         echo "export https_proxy=${proxy}" >> .profile.$$
	;;
   esac
}

unsetproxy() {
	setproxy "no"
}

pushd ${dir}/..

setproxy
[[ ! -n $noproxy ]] && . .profile.$$ 2>/dev/null
i=1
while [[ $i -gt 0 ]]; do
	$git_bin pull origin ${branch} >${logfile} 2>&1 && $r10k_bin puppetfile install --moduledir=${moduledir} --verbose >>${logfile} 2>&1
if [[ -n $(egrep -i "(could not resolve proxy|failed to connect)" ${logfile}) ]]; then
   unsetproxy
   [[ ! -n $noproxy ]] && . .profile.$$ 2>/dev/null 
   $git_bin pull origin ${branch} >>${logfile} 2>&1 && $r10k_bin puppetfile install --verbose >>${logfile} 2>&1
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
   $r10k_bin puppetfile install --moduledir=${moduledir} --verbose >>${logfile} 2>&1 && $puppet_bin apply --modulepath=modules:${moduledir}:'$basemodulepath' manifests/site.pp >>${logfile} 2>&1
else
   $puppet_bin apply --modulepath=modules:${moduledir}:'$basemodulepath' manifests/site.pp >>${logfile} 2>&1
fi

cd ${pwdir}
