#!/bin/bash

###
### THIS SCRIPT PROVIDES EXECUTION OF SERVICE CONTAINERS LOCALLY
###
### IT SHOULD __NOT__ BE CALLED INTERACTIVELY
###

if [ $(sed --version | head -1 | egrep GNU | wc -c) -gt 0 ]; then
  gnused=sed
elif [ -e /usr/local/opt/gnu-sed/libexec/gnubin/sed ]; then
  gnused=/usr/local/opt/gnu-sed/libexec/gnubin/sed
else
  echo "This script requires GNU sed; install with command: brew install gnu-sed" &> /dev/stderr
  exit 1
fi

# name
if [ -n "${1}" ]; then
  DOCKER_NAME="${1}"
else
  echo "*** ERROR -- -- $0 $$ -- DOCKER_NAME unspecified; exiting"
  exit 1
fi

# tag
if [ -n "${2}" ]; then
  DOCKER_TAG="${2}"
else
  echo "*** ERROR -- $0 $$ -- DOCKER_TAG unspecified; exiting"
  exit 1
fi

## configuration
if [ -z "${SERVICE:-}" ]; then SERVICE="config.json"; fi
if [ ! -s "${SERVICE}" ]; then echo "*** ERROR -- $0 $$ -- Cannot locate service configuration ${SERVICE}; exiting" &> /dev/stderr; exit 1; fi
SERVICE_LABEL=$(jq -r '.label' "${SERVICE}")

## privileged
if [ "$(jq '.privileged?!=null' "${SERVICE}" 2> /dev/null)" = true ]; then
  OPTIONS="${OPTIONS:-}"' --privileged'
fi

## host network
if [ "$(jq '.host_network?==true' "${SERVICE}" 2> /dev/null)" = true ]; then
  OPTIONS="${OPTIONS:-}"' --net=host'
fi

## input
#if [ -z "${USERINPUT:-}" ]; then USERINPUT="userinput.json"; fi
#if [ ! -s "${USERINPUT}" ] && [ "${DEBUG:-}" = true ]; then echo "+++ WARN -- $0 $$ -- cannot locate ${USERINPUT}; continuing" &> /dev/stderr; fi

# temporary file-system:  "tmpfs": "size=256m,uid=0,rw"

if [ $(jq '.tmpfs!=null' "${SERVICE}") = true ]; then
  TFS=($(jq -r '.tmpfs' ${SERVICE} | sed 's/,/ /g'))
  # size
  TM=$(jq -r '.tmpfs.size' ${SERVICE})
  if [ -z "${TS}" ] || [ "${TS}" == 'null' ]; then
    if [ "${DEBUG:-}" = true ];  then echo "--- INFO -- $0 $$ -- temporary filesystem; no size specified; defaulting to 4 Mbytes" &> /dev/stderr; fi
    TS=4096000
  fi
  # destination
  TM=$(jq -r '.tmpfs.destination' ${SERVICE})
  if [ -z "${TD}" ] || [ "${TD}" == 'null' ]; then
    if [ "${DEBUG:-}" = true ]; then echo "--- INFO -- $0 $$ -- temporary filesystem; no destination specified; defaulting to /tmpfs" &> /dev/stderr; fi
    TD="/tmpfs"
  fi
  # mode
  TM=$(jq -r '.tmpfs.mode' ${SERVICE})
  if [ -z "${TM}" ] || [ "${TM}" == 'null' ]; then
    if [ "${DEBUG:-}" = true ]; then echo "--- INFO -- $0 $$ -- temporary filesystem; no mode specified; defaulting to 1777" &> /dev/stderr; fi
    TM="1777"
  fi
  OPTIONS="${OPTIONS:-}"' --mount type=tmpfs,destination='"${TD}"',tmpfs-size='"${TS}"',tmpfs-mode='"${TM}"
else
  if [ "${DEBUG:-}" = true ]; then echo "--- INFO -- $0 $$ -- no tmpfs" &> /dev/stderr; fi
fi

# extra mounts
if [ $(jq '.mount!=null' "${SERVICE}") = true ]; then
  mounts=$(jq '.mount|to_entries' "${SERVICE}")
  keys=$(echo "${mounts}" | jq '.[]|.key')
  for key in ${keys}; do
    mount=$(echo "${mounts}" | jq '.[]|select(.key=='${key}').value')
    source=$(echo "${mount}" | jq -r '.source' | envsubst)
    target=$(echo "${mount}" | jq -r '.target' | envsubst)

    if [ -e "${source}" ]; then
      OPTIONS="${OPTIONS} --mount type=bind,source=${source},target=${target}"
    else
      echo "*** ERROR -- $0 $$ -- no source: ${source}; not mounted into ${target}" &> /dev/stderr
    fi
  done
else
  if [ "${DEBUG:-}" = true ]; then echo "--- INFO -- $0 $$ -- no mount" &> /dev/stderr; fi
fi

# inputs
if [ "$(jq '.userInput!=null' ${SERVICE})" = true ]; then
  URL=$(jq -r '.url' ${SERVICE})
  NAMES=$(jq -r '.userInput[].name' ${SERVICE})
  for NAME in ${NAMES}; do
    DV=$(jq -r '.userInput[]|select(.name=="'$NAME'").defaultValue' ${SERVICE})
    if [ -s "${USERINPUT}" ]; then
      VAL=$(jq -r '.services[]|select(.url=="'${URL}'").variables|to_entries[]|select(.key=="'${NAME}'").value' ${USERINPUT})
    fi
    if [ -s "${NAME}" ]; then
       VAL=$(sed 's/^"\(.*\)"$/\1/' "${NAME}")
    fi
    if [ -n "${VAL}" ] && [ "${VAL}" != 'null' ]; then
      DV=${VAL};
    elif [ "${DV}" == 'null' ]; then
      echo "*** ERROR -- $0 $$ -- value NOT defined for required: ${NAME}; create file ${NAME} with JSON value; exiting"
      exit 1
    fi
    OPTIONS="${OPTIONS:-}"' -e '"${NAME}"'='"${DV}"
  done
else
  if [ "${DEBUG:-}" = true ]; then echo "+++ WARN -- $0 $$ -- no inputs" &> /dev/stderr; fi
fi

# ports
for i in $(jq -r '.ports|to_entries[].value' ${SERVICE} ); do 
  for P in $(jq -r '.ports|to_entries[]|select(.value=='${i}').key' ${SERVICE}); do
    HOST_PORT=$(echo "${P}" | sed 's/\([0-9]*\).*/\1/')
    if [ -z "${HOST_PORT}" ]; then
      echo "*** ERRROR: no port specified: ${P}; continuing" &> /dev/stderr
      continue
    fi
    CONTAINER_PORT=${i}
    if [ -z "${CONTAINER_PORT}" ]; then CONTAINER_PORT=${HOST_PORT}; fi
    if [ "${SERVICE_PORT}" -eq "${CONTAINER_PORT:-}" ]; then
      echo "+++ WARN -- $0 $$ -- service port: ${CONTAINER_PORT}; continuing" &> /dev/stderr
      continue
    fi
    if [ "${DEBUG:-}" = true ]; then echo "--- INFO -- $0 $$ -- mapping service port: ${CONTAINER_PORT} to host port: ${HOST_PORT}" &> /dev/stderr; fi
    OPTIONS="${OPTIONS:-}"' --publish='"${HOST_PORT}"':'"${CONTAINER_PORT}"
  done
done

if [ ! -z "${SERVICE_PORT:-}" ]; then
  if [ -z "${DOCKER_PORT}" ]; then DOCKER_PORT=${SERVICE_PORT}; fi
  if [ "${DEBUG:-}" = true ]; then echo "--- INFO -- $0 $$ -- mapping service port: ${SERVICE_PORT} to host port: ${DOCKER_PORT}" &> /dev/stderr; fi
  OPTIONS="${OPTIONS:-}"' --publish='"${DOCKER_PORT}"':'"${SERVICE_PORT}"
else
 if [ "${DEBUG:-}" = true ]; then echo "+++ WARN -- $0 $$ -- no ports mapped" &> /dev/stderr; fi
fi

if [ "${DEBUG:-}" = true ]; then echo "--- INFO -- $0 $$ -- docker run -d --name ${DOCKER_NAME} ${OPTIONS} ${DOCKER_TAG}" &> /dev/stderr; fi

## environment
EVARS=$(jq '.options' ${SERVICE} | ${gnused} -e 's/"\!secret \(.*\)"/\$\{\U\1\}/' -e 's/-/_/g' | egrep '\$' | awk '{ print $2 }' | sed 's/\${\(.*\)\}.*/\1/' 2> /dev/null)
if [ "${EVARS}" != 'null' ]; then
  for e in ${EVARS}; do
    E=$(eval echo $(echo '${'${e}':-}'))
    if [ ! -z "${E:-}" ]; then
      echo "--- INFO -- $0 $$ -- Variable ${e} to ${E} from environment" &> /dev/stderr
      EXPORTS="${EXPORTS:-} ${e}=${E}"
      OPTIONS="${OPTIONS:-}"' -e '"${e}=${E}"
    elif [ -s "${e}" ]; then
      E=$(cat ${e})
      if [ ! -z "${E:-}" ]; then
        echo "--- INFO -- $0 $$ -- Variable ${e} to ${E} from file" &> /dev/stderr
        EXPORTS="${EXPORTS:-} ${e}=${E}"
        OPTIONS="${OPTIONS:-}"' -e '"${e}=${E}"
      fi
    else
      echo "--- INFO -- $0 $$ -- Variable ${e} unset; no environment or file" &> /dev/stderr
    fi
  done
fi

# make data
DATADIR=$(pwd -P)/data
mkdir -p ${DATADIR}
export ${EXPORTS} \
  && jq '.options' config.json \
  | ${gnused} -e 's/"\!secret \(.*\)"/"\$\{\U\1\}"/' -e 's/-/_/g' \
  | envsubst \
  > ${DATADIR}/options.json

for option in $(jq -r '.options|to_entries[].key' ${SERVICE} ); do 
  if [ -s ${option}.json ]; then 
    jq '.'"${option}"'='"$(cat ${option}.json)" ${DATADIR}/options.json \
      > ${DATADIR}/options.json.$$ \
    && mv -f ${DATADIR}/options.json.$$ ${DATADIR}/options.json
  fi
done

echo docker run \
  --name "${DOCKER_NAME}" \
  -d \
  --restart=unless-stopped \
  --mount "type=bind,source=${DATADIR},target=/data" \
  -e LOG_LEVEL=6 \
  ${OPTIONS} \
  "${DOCKER_TAG}" &> /dev/stderr

docker run \
  --name "${DOCKER_NAME}" \
  -d \
  --restart=unless-stopped \
  --mount "type=bind,source=${DATADIR},target=/data" \
  -e LOG_LEVEL=6 \
  ${OPTIONS} \
  "${DOCKER_TAG}" &> /dev/stderr
