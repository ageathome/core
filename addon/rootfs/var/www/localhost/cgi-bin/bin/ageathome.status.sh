#!/bin/bash

motion.restart()
{
  local host=${1:-localhost}
  local port=${2:-8080}
  local camera=${3:-}

  local cameras=($(motion.status ${host} ${port} | jq -r '.cameras?[].camera?'))

  echo -n '{"host":"'${host}'","port":'${port}',"cameras":['
  if [ ${#cameras[@]} -gt 0 ]; then
    i=1; j=0
    for c in ${cameras[@]}; do
      if [ -z "${camera:-}" ] || [ "${c:-}" = "${camera}" ]; then
        if [ ${j} -gt 1 ]; then echo ','; fi
        r=$(curl -sqSL --connect-timeout 10 ${host}:${port}/${i}/action/restart &> /dev/null && echo '{}' | jq '.id='${i}'|.camera="'${c}'"|.status="restarted"')
        echo -n "${r}"
        j=$((j+1))
      fi
      i=$((i+1))
    done
  fi
  echo ']}'
}

ageathome.status()
{
  local status

  if [ -s "/tmp/valid.json" ]; then
    status=$(jq -Sc . "/tmp/valid.json")
  fi
  echo "${status:-null}"
}

motion.status()
{
  local host=${1:-localhost}
  local port=${2:-8080}
  local options="$(${0%/*}/options.sh 2> /dev/null)"
  if [ "${options:-null}" != 'null' ]; then
    local nnetcam=$(echo "${options}" | jq '[.cameras[]|select(.type=="netcam")]|length')
    local nlocal=$(echo "${options}" | jq '[.cameras[]|select(.type=="local")]|length')
    local ndaemon=$(echo "$((nnetcam + nlocal)) / 3" | bc)
    local i=0

    echo -n '{"host":"'${host}'","daemons":['
    while [ ${i:-0} -le ${ndaemon:-0} ]; do
      if [ ${i} -gt 0 ]; then echo ','; fi
      echo '{"port":'${port}',"cameras":['
      echo $(daemon.status ${host} ${port})
      echo ']}'
      port=$((port+1))
      i=$((i+1))
    done
    echo ']}'
  else
    echo 'null'
  fi
}

daemon.status()
{
  local host=${1:-localhost}
  local port=${2:-8080}
  local cameras=($(curl --connect-timeout 10 -qsSL http://${host}:${port}/0/detection/status 2> /dev/null | awk '{ print $5 }'))

  if [ ${#cameras[@]} -gt 0 ]; then
    i=1
    for c in ${cameras[@]}; do
      if [ ${i} -gt 1 ]; then echo ','; fi
      if [ "${c:-}" = 'ACTIVE' ]; then
        r=$(curl --connect-timeout 10 -sqSL ${host}:${port}/${i}/detection/connection 2> /dev/null \
             | tail +2 \
             | awk '{ printf("{\"camera\":\"%s\",\"status\":\"%s\"}\n",$4,$6) }' \
             | jq '.id='${i}'|.status=(.status=="OK")')
          echo -n "${r}"
      fi
      i=$((i+1))
    done
  fi
}

###
### MAIN
###

CMD=${0##*/} && CMD=${CMD%%.sh*} && ${CMD} ${*} | jq -c '.'
