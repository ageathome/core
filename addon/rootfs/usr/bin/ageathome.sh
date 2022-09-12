#!/usr/bin/with-contenv bashio

### setup

function addon::setup.update()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local c="${1:-}"
  local e="${2:-}"
  local update

  new=$(jq -r '.'"${c}"'?' "$(motion.config.file)")
  old=$(jq -r '.'"${e}"'?' /config/setup.json)

  if [ "${new:-null}" != 'null' ] &&  [ "${old:-}" != "${new:-}" ]; then
    jq -Sc '.timestamp="'$(date -u '+%FT%TZ')'"|.'"${e}"'="'"${new:-none}"'"' /config/setup.json > /tmp/setup.json.$$ && mv -f /tmp/setup.json.$$ /config/setup.json && bashio::log.debug "Updated ${e}: ${new:-none}; old: ${old}" && update=1 || bashio::log.debug "Could not update ${e} to ${new:-none}"
  elif [ "${new:-null}" == 'null' ] &&  [ "${old:-}" == "null" ]; then
    jq -Sc '.timestamp="'$(date -u '+%FT%TZ')'"|.'"${e}"'="'"${new:-none}"'"' /config/setup.json > /tmp/setup.json.$$ && mv -f /tmp/setup.json.$$ /config/setup.json && bashio::log.debug "Initialized ${e}: ${new:-none}" && update=1 || bashio::log.debug "Could not initialize ${e} to ${new:-none}"
  else
    bashio::log.debug "${FUNCNAME[0]} no change ${e}: ${old}; new: ${new:-none}"
  fi
  echo ${update:-0}
}

function addon::setup.reload()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  if [ "$(bashio::config 'reload')" != 'false' ] && [ -e /config/setup.json ]; then
    local update=0
    local i=2
    local old
    local new
    local tf

    while true; do
      bashio::log.debug "Option 'reload' is true; querying for ${i} seconds at ${MOTION_APACHE_HOST}:${MOTION_APACHE_PORT}"
      local config=$(curl -sSL -m ${i} ${MOTION_APACHE_HOST}:${MOTION_APACHE_PORT}/cgi-bin/config 2> /dev/null || true)

      config=$(echo "${config}" | jq '.config?')
      if [ "${config:-null}" != 'null' ]; then

        # check configuration (timezone, latitude, longitude, mqtt, group, device, client)
        if [ -e /config/setup.json ]; then
          # site
          tf=$(addon::setup.update 'site' 'MOTION_SITE') && update=$((update+tf))
          # w3w
          tf=$(addon::setup.update 'w3w.apikey' 'MOTION_W3W_APIKEY') && update=$((update+tf))
          tf=$(addon::setup.update 'w3w.words' 'MOTION_W3W_WORDS') && update=$((update+tf))
          # uptimerobot 
          tf=$(addon::setup.update 'uptimerobot_rssurl' 'UPTIMEROBOT_RSSURL') && update=$((update+tf))
          # iperf
          tf=$(addon::setup.update 'iperf_host' 'IPERF_HOST') && update=$((update+tf))
          # router
          tf=$(addon::setup.update 'router_name' 'MOTION_ROUTER_NAME') && update=$((update+tf))
          # host
          tf=$(addon::setup.update 'interface' 'HOST_INTERFACE') && update=$((update+tf))
          tf=$(addon::setup.update 'ipaddr' 'HOST_IPADDR') && update=$((update+tf))
          tf=$(addon::setup.update 'timezone' 'HOST_TIMEZONE') && update=$((update+tf))
          tf=$(addon::setup.update 'latitude' 'HOST_LATITUDE') && update=$((update+tf))
          tf=$(addon::setup.update 'longitude' 'HOST_LONGITUDE') && update=$((update+tf))
          # mqtt
          tf=$(addon::setup.update 'mqtt.host' 'MQTT_HOST') && update=$((update+tf))
          tf=$(addon::setup.update 'mqtt.password' 'MQTT_PASSWORD') && update=$((update+tf))
          tf=$(addon::setup.update 'mqtt.port' 'MQTT_PORT') && update=$((update+tf))
          tf=$(addon::setup.update 'mqtt.username' 'MQTT_USERNAME') && update=$((update+tf))
          # motion
          tf=$(addon::setup.update 'group' 'MOTION_GROUP') && update=$((update+tf))
          tf=$(addon::setup.update 'device' 'MOTION_DEVICE') && update=$((update+tf))
          tf=$(addon::setup.update 'client' 'MOTION_CLIENT') && update=$((update+tf))
          # overview
          tf=$(addon::setup.update 'overview.apikey' 'MOTION_OVERVIEW_APIKEY') && update=$((update+tf))
          tf=$(addon::setup.update 'overview.image' 'MOTION_OVERVIEW_IMAGE') && update=$((update+tf))
          tf=$(addon::setup.update 'overview.mode' 'MOTION_OVERVIEW_MODE') && update=$((update+tf))
          tf=$(addon::setup.update 'overview.zoom' 'MOTION_OVERVIEW_ZOOM') && update=$((update+tf))
          # USERS
          tf=$(addon::setup.update 'roles.person' 'MOTION_USER') && update=$((update+tf))
          tf=$(addon::setup.update 'roles.primary' 'MOTION_PRIMARY') && update=$((update+tf))
          tf=$(addon::setup.update 'roles.secondary' 'MOTION_SECONDARY') && update=$((update+tf))
          tf=$(addon::setup.update 'roles.tertiary' 'MOTION_TERTIARY') && update=$((update+tf))
          # DEVICES
          tf=$(addon::setup.update 'devices.person' 'MOTION_USER_DEVICE') && update=$((update+tf))
          tf=$(addon::setup.update 'devices.primary' 'MOTION_PRIMARY_DEVICE') && update=$((update+tf))
          tf=$(addon::setup.update 'devices.secondary' 'MOTION_SECONDARY_DEVICE') && update=$((update+tf))
          tf=$(addon::setup.update 'devices.tertiary' 'MOTION_TERTIARY_DEVICE') && update=$((update+tf))
        fi

        # test if update
        if [ ${update:-0} -gt 0 ]; then
          bashio::log.debug "Updated settings"
        else
          bashio::log.debug "No updates"
        fi
        break
      fi

      # no config; try again
      sleep ${i}
      i=$((i+i))
      if [ ${i:-0} -gt 30 ]; then
        # up to a limit
        bashio::log.error "Automatic reload failed waiting on Apache; use Terminal and run 'make restart'"
        break
      fi
    done
  elif [ ! -e /config/setup.json ]; then
    bashio::log.debug "Did not find /config/setup.json"
  else 
    bashio::log.debug "Reload off"
  fi
}

### apache

start_apache_foreground()
{
  start_apache true ${*}
}

start_apache_background()
{
  start_apache false ${*}
}

start_apache()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local foreground=${1}; shift

  local conf=${1}
  local host=${2}
  local port=${3}
  local admin="${4:-root@${host}}"
  local tokens="${5:-}"
  local signature="${6:-}"

  # edit defaults
  sed -i 's|^Listen .*|Listen '${port}'|' "${conf}"
  sed -i 's|^ServerName .*|ServerName '"${host}:${port}"'|' "${conf}"
  sed -i 's|^ServerAdmin .*|ServerAdmin '"${admin}"'|' "${conf}"

  # SSL
  if [ ! -z "${tokens:-}" ]; then
    sed -i 's|^ServerTokens.*|ServerTokens '"${tokens}"'|' "${conf}"
  fi
  if [ ! -z "${signature:-}" ]; then
    sed -i 's|^ServerSignature.*|ServerSignature '"${signature}"'|' "${conf}"
  fi

  # enable CGI
  sed -i 's|^\([^#]\)#LoadModule cgi|\1LoadModule cgi|' "${conf}"

  # export environment
  export MOTION_SHARE_DIR=$(motion.config.share_dir)

  # pass environment
  echo 'PassEnv MOTION_SHARE_DIR' >> "${conf}"

  # make /run/apache2 for PID file
  mkdir -p /run/apache2

  # make the add-on options available to the apache client
  chmod go+rx /data /data/options.json

  # start HTTP daemon
  bashio::log.debug "Starting Apache: ${conf} ${host} ${port}"

  if [ "${foreground:-false}" = 'true' ]; then
    httpd -E ${MOTION_LOGTO} -e debug -f "${MOTION_APACHE_CONF}" -DFOREGROUND
  else
    httpd -E ${MOTION_LOGTO} -e debug -f "${MOTION_APACHE_CONF}"
  fi
}

###
# configuration functions
###

function addon::config.option()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local e="${1:-}"
  local d="${2:-}"
  local VALUE=$(bashio::config "${e}") 

  if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then VALUE="${d}"; fi
  jq -Sc '.'"${e}"'="'"${VALUE}"'"' $(motion.config.file) > /tmp/$$.json \
    && mv -f /tmp/$$.json $(motion.config.file) \
    || bashio::log.error "Unable to update ${e} in $(motion.config.file)"

  echo "${VALUE:-}"
}

## overview

function addon::config.overview()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local apikey=$(addon::config.option overview.apikey "")
  local image=$(addon::config.option overview.image "overview.jpg")
  local mode=$(addon::config.option overview.mode "local")
  local zoom=$(addon::config.option overview.zoom 18)

  echo '{"apikey":"'${apikey:-}'","image":"'${image:-}'","mode":"'${mode:-}'","zoom":'${zoom:-18}'}'
}

## roles

function addon::config.roles()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local person=$(addon::config.option roles.person "")
  local primary=$(addon::config.option roles.primary "")
  local secondary=$(addon::config.option roles.secondary "")
  local tertiary=$(addon::config.option roles.tertiary "")

  echo '{"person":"'${person:-}'","primary":"'${primary:-}'","secondary":"'${secondary:-}'","tertiary":"'${tertiary:-}'"}'
}

## repo

function addon::config.repo()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local mai_url=$(addon::config.option motionai.url "https://github.com/motion-ai/motion-ai")
  local mai_tag=$(addon::config.option motionai.tag "dev")
  local mai_branch=$(addon::config.option motionai.branch "master")
  local mai_release=$(addon::config.option motionai.release "none")

  local aah_url=$(addon::config.option ageathome.url "https://github.com/ageathome/core")
  local aah_tag=$(addon::config.option ageathome.tag "dev")
  local aah_branch=$(addon::config.option ageathome.branch "master")
  local aah_release=$(addon::config.option ageathome.release "none")

  echo '{"motionai":{"url":"'${mai_url:-}'","release":"'${mai_release:-}'","branch":"'${mai_branch:-}'","tag":"'${mai_tag:-}'"},"ageathome":{"url":"'${aah_url:-}'","release":"'${aah_release:-}'","branch":"'${aah_branch:-}'","tag":"'${aah_tag:-}'"}}'
}

## location

function addon::config.location()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local elevation=$(addon::config.option elevation 0)
  local words=$(addon::config.option w3w.words "///what.three.words")
  local key=$(addon::config.option w3w.apikey "")
  local latitude=$(addon::config.option latitude 0)
  local longitude=$(addon::config.option longitude 0)
  local results

  if [ "${words:-null}" != 'null' ] && [ "${key:-null}" != 'null' ]; then
    results=$(curl -ksSL "https://api.what3words.com/v3/convert-to-coordinates?words=${words}&key=${key}" 2> /dev/null)
    if [ "${results:-null}" != 'null' ] && [ $(echo "${results}" | jq '.error!=null') != 'true' ]; then
      local lat=$(echo "${results}" | jq -r '.coordinates.lat')
      local lng=$(echo "${results}" | jq -r '.coordinates.lng')

      if [ "${lat:-null}" != 'null' ] && [ "${lng:-null}" != 'null' ]; then
        bashio::log.debug "Updating location with latitude=${lat}; longitude=${lng}"
        latitude=${lat}
        longitude=${lng}
      else
        bashio::log.error "No coordinates in W3W results: ${results:-null}"
      fi
    else
      bashio::log.debug "No W3W results: ${results:-null}"
    fi
  else
    bashio::log.debug "No W3W words or apikey: ${w3w:-null}"
  fi
  latitude=$(addon::config.option latitude ${latitude})
  longitude=$(addon::config.option longitude ${longitude})

  echo '{"latitude":'${latitude:-null}',"longitude":'${longitude:-null}',"elevation":'${elevation:-null}',"apikey":"'${key:-}'","words":"'${words}'","results":'${results:-null}'}'
}

## mqtt

function addon::config.mqtt()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local network="${1:-}"
  local ip=$(echo "${network:-null}" | jq -r '.ip?')
  local host
  local port=1883
  local username
  local password


  if [ $(bashio::services.available "mqtt") ]; then
    host=$(bashio::service 'mqtt' 'host')
    port=$(bashio::service 'mqtt' 'port')
    username=$(bashio::service 'mqtt' 'username')
    password=$(bashio::service 'mqtt' 'password')
  else
    bashio::log.debug "${FUNCNAME[0]}: MQTT service unavailable through supervisor; using configuration."
  fi

  if [ -z "${host:-}" ]; then 
    host=$(bashio::config "mqtt.host") 
    if [ "${host:-null}" = 'null' ]; then 
      host="${ip:-127.0.0.1}"
      bashio::log.debug "${FUNCNAME[0]}: MQTT host configuration undefined; using host IP address: ${host:-}"
    fi

    # set from configuration with defaults
    host=$(addon::config.option mqtt.host "${host}")
    port=$(addon::config.option mqtt.port "${port}")
    username=$(addon::config.option mqtt.username 'username')
    password=$(addon::config.option mqtt.password 'password')
  fi

  echo '{"host":"'${host:-}'","port":'${port:-null}',"username":"'${username:-}'","password":"'${password:-}'"}'
}

## timezone

function addon::config.timezone()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local config=$(curl -sSL -X GET -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" http://supervisor/core/api/config)
  local timezone=$(echo "${config:-null}" | jq -r '.time_zone?')

  if [ -z "${timezone:-}" ] || [ "${timezone:-null}" == 'null' ]; then
    timezone='GMT'
    bashio::log.debug "${FUNCNAME[0]} ${*} - setting timezone to default: ${timezone}"
  else
    bashio::log.debug "${FUNCNAME[0]} ${*} - timezone: ${timezone}"
  fi

  timezone=$(addon::config.option timezone "${timezone}")

  if [ -s "/usr/share/zoneinfo/${timezone}" ]; then
    cp /usr/share/zoneinfo/${timezone} /etc/localtime
    echo "${timezone}" > /etc/timezone
  else
    bashio::log.error "No known timezone: ${timezone}"
  fi
  echo "${timezone:-}"
}

## network

function addon::config.network()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"
  local ipaddr=$(ip addr \
                 | egrep -A4 UP \
                 | egrep 'inet ' \
                 | egrep -v 'scope host lo' \
                 | egrep -v 'scope global docker' \
                 | awk '{ print $2 }')

  jq -Sc '.ipaddr="'${ipaddr%%/*}'"' $(motion.config.file) > /tmp/$$.json \
    && mv -f /tmp/$$.json $(motion.config.file) \
    || bashio::log.error "Unable to update $(motion.config.file)"

  export ADDON_API="http://${ipaddr%%/*}:${MOTION_APACHE_PORT}"
  echo '{"ip":"'${ipaddr%%/*}'"}'
}

# options

function addon::config.options()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local config=$(curl -sSL -X GET -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" http://supervisor/core/api/config)
  local site=$(echo "${config:-null}" | jq -r '.location_name?')

  if [ -z "${site:-}" ] || [ "${site:-null}" == 'null' ]; then
    site='My House'
    bashio::log.debug "${FUNCNAME[0]} ${*} - Setting site to default: ${site}"
  else
    bashio::log.debug "${FUNCNAME[0]} ${*} - Found site: ${site}"
  fi
  site=$(addon::config.option site "${site}")

  local host=$(curl -sSL -X GET -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" http://supervisor/host/info)
  local device=$(echo "${host:-null}" | jq -r '.data.hostname?')
  if [ -z "${device:-}" ] || [ "${device:-null}" == 'null' ]; then
    device="$(hostname -s)"
    bashio::log.debug "${FUNCNAME[0]} ${*} - Setting device to default: ${device}"
  else
    bashio::log.debug "${FUNCNAME[0]} ${*} - Found device: ${device}"
  fi
  device=$(addon::config.option device "${device}")

  local rssurl=$(addon::config.option uptimerobot_rssurl "unknown")
  local iperf=$(addon::config.option iperf_host "127.0.0.1")
  local unit_system=$(addon::config.option unit_system "imperial")
  local group=$(addon::config.option group "motion")
  local client=$(addon::config.option client "+")
  local share_dir=$(addon::config.option share_dir "/share/${group:-motion}")

  echo '{"device":"'${device:-}'","iperf":"'${iperf:-}'","rssurl":"'${rssurl:-}'","unit_system":"'${unit_system:-}'","share_dir":"'${share_dir:-}'","site":"'${site:-}'","group":"'${group:-}'","client":"'${client:-}'"}'
}

# init

function addon::config.init()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local info=$(curl -sSL -X GET -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" http://supervisor/info)
  local host=$(curl -sSL -X GET -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" http://supervisor/host/info)
  local config=$(curl -sSL -X GET -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" http://supervisor/core/api/config)
  local services=$(curl -sSL -X GET -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" http://supervisor/services)

  local json='{"supervisor":{"services":'${services:-null}',"host":'${host:-null}',"config":'${config:-null}',"info":'${info:-null}'},"version":"'"${BUILD_VERSION:-}"'","config_path":"'"${CONFIG_PATH}"'","hostname":"'"$(hostname)"'","arch":"'$(arch)'","date":'$(date -u +%s)'}'

  bashio::log.debug "Initializing: $(motion.config.file)"
  echo "${json}" | jq -Sc '.' | tee $(motion.config.file) || bashio::log.debug "Failed to initialize: $(motion.config.file)"
}

## config

function addon::config()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local init=$(addon::config.init)
  local timezone=$(addon::config.timezone)
  local roles=$(addon::config.roles)
  local repo=$(addon::config.repo)
  local overview=$(addon::config.overview)
  local location=$(addon::config.location)
  local network=$(addon::config.network)
  local mqtt=$(addon::config.mqtt "${network:-}")
  local options=$(addon::config.options)

  echo '{"timezone":"'${timezone:-}'","location":'${location:-null}',"network":'${network:-null}',"overview":'${overview:-null}',"repo":'${repo:-null}',"roles":'${roles:-null}',"mqtt":'${mqtt:-null}',"options":'${options:-null}',"init":'${init:-null}'}'
}

###
### MAIN
###

## INITIATE LOGGING

export MOTION_LOG_LEVEL="${1:-debug}"
export MOTION_LOGTO=${MOTION_LOGTO:-/tmp/motion.log}

## SOURCE TOOLS

source ${USRBIN:-/usr/bin}/motion-tools.sh

###
## configuration
###

CONFIG=$(addon::config)
if [ ! -s "$(motion.config.file)" ]; then
  bashio::log.fatal "Cannot find file: $(motion.config.file)"
  # rm -fr /config/setup.json /etc/motion /share/ageathome /share/motionai
  exit 1
elif [ "${CONFIG:-null}" == 'null' ]; then
  bashio::log.fatal "No configuration"
  exit 1
else
  bashio::log.debug "${CONFIG:-}"
fi

###
# start Apache
###

if [ ! -s "${MOTION_APACHE_CONF}" ]; then
  bashio::log.error "Missing Apache configuration"
  exit 1
fi
if [ -z "${MOTION_APACHE_HOST:-}" ]; then
  bashio::log.error "Missing Apache ServerName"
  exit 1
fi
if [ -z "${MOTION_APACHE_HOST:-}" ]; then
  bashio::log.error "Missing Apache ServerAdmin"
  exit 1
fi
if [ -z "${MOTION_APACHE_HTDOCS:-}" ]; then
  bashio::log.error "Missing Apache HTML documents directory"
  exit 1
fi

##
## apache
##

start_apache_background ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}
bashio::log.debug "Started Apache on ${MOTION_APACHE_HOST}:${MOTION_APACHE_PORT}"

##
## motionai
##

tag=$(echo "${CONFIG:-null}" | jq -r '.repo.motionai.tag?')
branch=$(echo "${CONFIG:-null}" | jq -r '.repo.motionai.branch?')
release=$(echo "${CONFIG:-null}" | jq -r '.repo.motionai.release?')

if [ "${tag:-null}" == 'release' ] && [ "${release:-}" = 'none' ] && [ "${release:-null}" = 'null' ]; then
  bashio::log.debug "motionai - no release specified; defaulting to latest"
  release='latest'
fi

if [ "${tag:-null}" == 'dev' ] && [ "${branch:-}" != 'master' ]; then
  bashio::log.debug "motionai branch ${branch} not supported (yet); defaulting to master"
  branch='master'
else 
  bashio::log.debug "motionai branch: ${branch}"
fi

if [ "${tag:-dev}" != 'dev' ]; then
  bashio::log.debug "motionai - tag ${tag}; release: ${release} not supported (yet); defaulting to dev"
  tag='dev'
else
  bashio::log.debug "motionai tag: ${tag}"
fi

# dev: download
if [ "${tag:-dev}" == 'dev' ]; then
  if [ ! -d /share/motion-ai ]; then
    url=$(echo "${CONFIG:-null}" | jq -r '.repo.motionai.url?')
    bashio::log.debug "motionai url: ${url}"
  
    bashio::log.debug "Cloning /share/motion-ai"
    git clone http://github.com/motion-ai/motion-ai /share/motion-ai &> /dev/null || bashio::log.warning "git clone failed"
    INIT=1
  else
    bashio::log.debug "Exists: /share/motion-ai"
  fi
fi

# release: download
if [ "${release:-null}" != 'null' ] && [ "${release:-null}" != 'latest' ]; then
  download=/share/motionai-${release##*/}

  if [ -s "${download}" ]; then
    tar tzf ${download} > /dev/null \
      && \
      bashio::log.debug "motionai - inspected ${download}; no download required" \
      || \
      rm -f "${download}"
  fi

  if [ ! -s ${download} ]; then
    curl -ksSL "${release}" -o ${download} 2> /dev/null \
      && \
      bashio::log.debug "motionai - downloaded ${release} into ${download}" \
      ||
      bashio::log.debug "motionai - failed to download release: ${release:-null}"
  fi

  if [ -s "${download}" ]; then
    tar tzf ${download} > /dev/null \
      && \
      bashio::log.debug "motionai - successfully inspected: ${download}" \
      || \
      bashio::log.debug "motionai - failed to inspect: ${download}"
  fi

else
  bashio::log.debug "motionai release: ${release} not supported (yet)"
fi

# dev: update
if [ "${tag:-dev}" == 'dev' ]; then
  if [ -d /share/motion-ai ]; then
    pushd /share/motion-ai &> /dev/null || bashio::log.warning "popd failed"
    bashio::log.debug "Updating /share/motion-ai"
    git checkout . &> /dev/null || bashio::log.warning "git checkout failed"
    git pull &> /dev/null || bashio::log.warning "git pull failed"
    popd &> /dev/null || bashio::log.warning "popd failed"
  else
    bashio::log.fatal "Cannot find /share/motion-ai"
    exit 1
  fi
fi

##
## ageathome
##

tag=$(echo "${CONFIG:-null}" | jq -r '.repo.ageathome.tag?')
branch=$(echo "${CONFIG:-null}" | jq -r '.repo.ageathome.branch?')
release=$(echo "${CONFIG:-null}" | jq -r '.repo.ageathome.release?')

if [ "${tag:-dev}" != 'dev' ]; then
  bashio::log.debug "ageathome - tag ${tag}; release: ${release} not supported (yet); defaulting to dev"
  tag='dev'
else
  bashio::log.debug "ageathome tag: ${tag}"
fi

if [ "${tag:-dev}" == 'dev' ]; then
  if [ ! -d /share/ageathome ]; then
    url=$(echo "${CONFIG:-null}" | jq -r '.repo.ageathome.url?')
    bashio::log.debug "ageathome url: ${url}"

    bashio::log.debug "Cloning /share/ageathome"
    git clone http://github.com/ageathome/core /share/ageathome &> /dev/null || bashio::log.warning "git clone failed"
    INIT=1
  else
    bashio::log.debug "Exists: /share/ageathome"
  fi
elif [ "${tag:-dev}" == 'release' ]; then
  bashio::log.debug "ageathome - release"
else
  bashio::log.debug "ageathome - update tag: ${tag}; release: ${release}: not supported (yet)"
fi

if [ "${tag:-dev}" == 'dev' ]; then
  if [ -d /share/ageathome ]; then

    if [ "${branch:-}" != 'master' ]; then
      bashio::log.debug "ageathome branch ${branch} not supported (yet); defaulting to master"
      branch='master'
    else 
      bashio::log.debug "ageathome branch: ${branch}"
    fi
    pushd /share/ageathome &> /dev/null || bashio::log.warning "pushd failed"
    if [ ! -e motion-ai ] && [ -d /share/motion-ai ]; then
      bashio::log.debug "Linking /share/motion-ai"
      ln -s /share/motion-ai .
    elif [ ! -d /share/motion-ai ]; then
      bashio::log.error "Could not link to /share/motion-ai"
    fi
    bashio::log.debug "Updating /share/ageathome"
    git checkout . &> /dev/null || bashio::log.warning "git checkout failed"
    git pull &> /dev/null || bashio::log.warning "git pull failed"
    popd &> /dev/null || bashio::log.warning "popd failed"
  else
    bashio::log.fatal "Cannot find /share/ageathome"
    exit 1
  fi
fi

# HOST_NAME
host=$(curl -sSL -X GET -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" http://supervisor/host/info)
host_name=$(echo "${host:-null}" | jq -r '.data.hostname?')
if [ -z "${host_name:-}" ] || [ "${host_name:-null}" == 'null' ]; then
    host_name='homeassistant'
    bashio::log.debug "Setting host name to default: ${host_name}"
else
    bashio::log.debug "Found host name: ${host_name}"
fi

## setup.json

if [ ! -e /config/setup.json ]; then
  bashio::log.debug "Initializing /share/ageathome"
  pushd /share/ageathome &> /dev/null || bashio::log.warning "pushd failed"
  MOTION_APP="Age@Home" \
    HOST_NAME="${host_name}" \
    HOST_IPADDR="$(echo "${CONFIG:-null}" | jq -r '.network.ip')" \
    make homeassistant/setup.json &> /dev/null \
    && \
    mv homeassistant/setup.json /config
  popd &> /dev/null || bashio::log.warning "popd failed"
  INIT=1
fi

addon::setup.reload

###
# update configuration
###

if [ -d /share/ageathome ] && [ -d /share/motion-ai ] && [ -e /config/setup.json ]; then
  bashio::log.debug "Updating /config from /share/ageathome/homeassistant at $(date)"
  pushd /share/ageathome/homeassistant &> /dev/null || bashio::log.warning "pushd failed"
  todo=($(ls -1))
  rsync -a -L --delete "${todo[@]}" /config/ && bashio::log.info "Synchronization successful at $(date)" || bashio::log.warning "Synchronization failed at $(date)"
  popd &> /dev/null || bashio::log.warning "popd failed"
  bashio::log.debug "Making /config at $(date)"
  pushd /config &> /dev/null || bashio::log.warning "pushd failed"
  MOTION_APP="Age@Home" \
    HOST_NAME="${host_name}" \
    HOST_IPADDR="$(echo "${CONFIG:-null}" | jq -r '.network.ip')" \
    PACKAGES="" \
    make &> /dev/null
  popd &> /dev/null || bashio::log.warning "popd failed"
  bashio::log.notice "Configuration complete at $(date)"
elif [ ! -e /config/setup.json ]; then
  bashio::log.fatal "Cannot find /config/setup.json"
  exit 1
elif [ ! -d /share/ageathome ]; then
  bashio::log.fatal "Cannot find /share/ageathome"
  exit 1
elif [ ! -d /share/motion-ai ]; then
  bashio::log.fatal "Cannot find /share/motion-ai"
  exit 1
fi

## reboot host if INIT=1
if [ ${INIT:-0} != 0 ]; then
  reboot=$(jq '.supervisor.info.data.features|index("reboot")>=0' "$(motion.config.file)")
  if [ "${reboot:-false}" = 'true' ]; then
    TEMP=$(mktemp)

    bashio::log.notice "Requesting host reboot for intitialization in 10 seconds ..."
    sleep 10
    reboot=$(curl -w '%{http_code}' -sSL -X POST -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" http://supervisor/host/reboot -o ${TEMP})
    case ${reboot} in
      403)
        bashio::log.notice "Reboot forbidden; please manually reboot."
        bashio::log.debug "$(jq -Sc . ${TEMP})"
        ;;
      404)
        bashio::log.notice "Reboot not found; please manually reboot."
        bashio::log.debug "$(jq -Sc . ${TEMP})"
        ;;
      200)
        bashio::log.notice "Reboot initiated."
        ;;
      *)
        bashio::log.notice "Reboot unknown: ${reboot:-null}; please reboot manually."
        bashio::log.debug "$(jq -Sc . ${TEMP})"
        ;;
    esac
  else
    bashio::log.notice "No reboot feature available; manual reboot required!"
  fi
  rm -f "${TEMP:-}"
fi

## forever
while true; do

    ## publish configuration
    ( motion.mqtt.pub -r -q 2 -t "$(motion.config.group)/$(motion.config.device)/start" -f "$(motion.config.file)" &> /dev/null \
      && bashio::log.info "Published configuration to MQTT; topic: $(motion.config.group)/$(motion.config.device)/start" ) \
      || bashio::log.debug "Failed to publish configuration to MQTT; config: $(motion.config.mqtt)"

    ## sleep
    bashio::log.debug "Sleeping at $(date); ${MOTION_WATCHDOG_INTERVAL:-1800} seconds ..."
    sleep ${MOTION_WATCHDOG_INTERVAL:-1800}
    bashio::log.debug "Updating addons"
    curl -sSL -X GET -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" http://supervisor/addons/reload &> /dev/null

done
