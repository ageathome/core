#!/bin/bash

find_status()
{
  result="$(${0%/*}/motion.status.sh)"

  if [ "${result:-null}" != 'null' ]; then
    echo '{"timestamp":"'$(date -u +%FT%TZ)'","status":'"${result:-null}"'}'
  else
    echo '{"timestamp":"'$(date -u +%FT%TZ)'","error":"no status"}'
  fi
}

###
### MAIN
###

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo "*** ERROR -- $0 $$ -- provide fullpath for output file and pidfile" &>  /dev/stderr
  exit 1
fi

output=${1:-}
pidfile=${2:-}
temp=$(mktemp)

echo $$ > ${pidfile}

exec 0>&- # close stdin
exec 1>&- # close stdout
exec 2>&- # close stderr

# doit
echo "$(find_status)" | jq -c '.' > ${temp}

mv -f ${temp} ${output}
chmod 444 ${output}
rm -f ${pidfile}
