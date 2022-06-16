#!/usr/bin/with-contenv bashio

## initiate logging
export MOTION_LOG_LEVEL="${1:-debug}"
export MOTION_LOGTO=${MOTION_LOGTO:-/tmp/motion.log}

source ${USRBIN:-/usr/bin}/motion-tools.sh

###
### PRE-FLIGHT
###

## motion command
MOTION_CMD=$(command -v motion)
if [ ! -s "${MOTION_CMD}" ]; then
  bashio::log.error "Motion not installed; command: ${MOTION_CMD}"
  exit 1
fi

bashio::log.debug "Reseting configuration to default: ${MOTION_CONF}"
cp -f ${MOTION_CONF%%.*}.default ${MOTION_CONF}

## defaults
if [ -z "${MOTION_CONTROL_PORT:-}" ]; then MOTION_CONTROL_PORT=8080; fi
if [ -z "${MOTION_STREAM_PORT:-}" ]; then MOTION_STREAM_PORT=8090; fi


## apache
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


###
## FUNCTIONS
###

## updateSetup
function motion::setup.update()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  local c="${1:-}"
  local e="${2:-}"
  local update

  old="$(jq -r '.'"${e}"'?' /config/setup.json)"
  new=$(jq -r '.'"${c}"'?' "/data/options.json")

  if [ "${new:-null}" != 'null' ] &&  [ "${old:-}" != "${new:-}" ]; then
    jq -c '.timestamp="'$(date -u '+%FT%TZ')'"|.'"${e}"'="'"${new}"'"' /config/setup.json > /tmp/setup.json.$$ && mv -f /tmp/setup.json.$$ /config/setup.json
    bashio::log.info "Updated ${e}: ${new}; old: ${old}"
    update=1
  else
    bashio::log.debug "${FUNCNAME[0]} no change ${e}: ${old}; new: ${new}"
  fi
  echo ${update:-0}
}

## reload
function motion::reload()
{
  bashio::log.trace "${FUNCNAME[0]} ${*}"

  if [ $(bashio::config 'reload') = 'true' ]; then
    local update=0
    local date='null'
    local i=2
    local old
    local new
    local tf

    while true; do
      bashio::log.notice "Option 'reload' is true; querying for ${i} seconds at ${MOTION_APACHE_HOST}:${MOTION_APACHE_PORT}"
      local config=$(curl -sSL -m ${i} ${MOTION_APACHE_HOST}:${MOTION_APACHE_PORT}/cgi-bin/config 2> /dev/null || true)

      config=$(echo "${config}" | jq '.config?')
      if [ "${config:-null}" != 'null' ]; then

        # update if cameras changed
        if [ -e /config/motion/config.json ]; then
          old=$(jq -c -S '.config.cameras' /config/motion/config.json)
          new=$(echo "${config}" | jq -c -S '.cameras')

          if [ "${new:-null}" != 'null' ] && [ "${old:-}" != "${new:-}" ]; then
            bashio::log.info "Cameras updated"
            update=$((update+1))
          fi
        fi

        # check configuration (timezone, latitude, longitude, mqtt, group, device, client)
        if [ -e /config/setup.json ]; then
          # ww3
          tf=$(motion::setup.update 'w3w.apikey' 'MOTION_W3W_APIKEY') && update=$((update+tf))
          tf=$(motion::setup.update 'w3w.words' 'MOTION_W3W_WORDS') && update=$((update+tf))
          tf=$(motion::setup.update 'w3w.email' 'MOTION_W3W_EMAIL') && update=$((update+tf))
          # camera_restart
          tf=$(motion::setup.update 'camera_restart' 'MOTION_CAMERA_RESTART') && update=$((update+tf))
          # camera_any
          tf=$(motion::setup.update 'camera_any' 'MOTION_CAMERA_ANY') && update=$((update+tf))
          # router
          tf=$(motion::setup.update 'router_name' 'MOTION_ROUTER_NAME') && update=$((update+tf))
          # host
          tf=$(motion::setup.update 'interface' 'HOST_INTERFACE') && update=$((update+tf))
          tf=$(motion::setup.update 'ipaddr' 'HOST_IPADDR') && update=$((update+tf))
          tf=$(motion::setup.update 'timezone' 'HOST_TIMEZONE') && update=$((update+tf))
          tf=$(motion::setup.update 'latitude' 'HOST_LATITUDE') && update=$((update+tf))
          tf=$(motion::setup.update 'longitude' 'HOST_LONGITUDE') && update=$((update+tf))
          # mqtt
          tf=$(motion::setup.update 'mqtt.host' 'MQTT_HOST') && update=$((update+tf))
          tf=$(motion::setup.update 'mqtt.password' 'MQTT_PASSWORD') && update=$((update+tf))
          tf=$(motion::setup.update 'mqtt.port' 'MQTT_PORT') && update=$((update+tf))
          tf=$(motion::setup.update 'mqtt.username' 'MQTT_USERNAME') && update=$((update+tf))
          # motion
          tf=$(motion::setup.update 'group' 'MOTION_GROUP') && update=$((update+tf))
          tf=$(motion::setup.update 'device' 'MOTION_DEVICE') && update=$((update+tf))
          tf=$(motion::setup.update 'client' 'MOTION_CLIENT') && update=$((update+tf))
          # media
          tf=$(motion::setup.update 'media.save' 'MOTION_MEDIA_SAVE') && update=$((update+tf))
          tf=$(motion::setup.update 'media.mask' 'MOTION_MEDIA_MASK') && update=$((update+tf))
          # overview
          tf=$(motion::setup.update 'overview.apikey' 'MOTION_OVERVIEW_APIKEY') && update=$((update+tf))
          tf=$(motion::setup.update 'overview.image' 'MOTION_OVERVIEW_IMAGE') && update=$((update+tf))
          tf=$(motion::setup.update 'overview.mode' 'MOTION_OVERVIEW_MODE') && update=$((update+tf))
          tf=$(motion::setup.update 'overview.zoom' 'MOTION_OVERVIEW_ZOOM') && update=$((update+tf))
          # yolo
          tf=$(motion::setup.update 'yolo.config' 'MOTION_YOLO_CONFIG') && update=$((update+tf))
          tf=$(motion::setup.update 'yolo.ip' 'MOTION_YOLO_IP') && update=$((update+tf))
          # USER
          tf=$(motion::setup.update 'person.user' 'MOTION_USER') && update=$((update+tf))
          # detected.person
          tf=$(motion::setup.update 'person.entity' 'MOTION_DETECTED_PERSON_ENTITY') && update=$((update+tf))
          tf=$(motion::setup.update 'person.ago' 'MOTION_DETECTED_PERSON_AGO') && update=$((update+tf))
          tf=$(motion::setup.update 'person.deviation' 'MOTION_DETECTED_PERSON_DEVIATION') && update=$((update+tf))
          tf=$(motion::setup.update 'person.notify' 'MOTION_DETECTED_PERSON_NOTIFY') && update=$((update+tf))
          tf=$(motion::setup.update 'person.speak' 'MOTION_DETECTED_PERSON_SPEAK') && update=$((update+tf))
          tf=$(motion::setup.update 'person.tune' 'MOTION_DETECTED_PERSON_TUNE') && update=$((update+tf))
          # detected.vehicle
          tf=$(motion::setup.update 'vehicle.entity' 'MOTION_DETECTED_VEHICLE_ENTITY') && update=$((update+tf))
          tf=$(motion::setup.update 'vehicle.ago' 'MOTION_DETECTED_VEHICLE_AGO') && update=$((update+tf))
          tf=$(motion::setup.update 'vehicle.deviation' 'MOTION_DETECTED_VEHICLE_DEVIATION') && update=$((update+tf))
          tf=$(motion::setup.update 'vehicle.notify' 'MOTION_DETECTED_VEHICLE_NOTIFY') && update=$((update+tf))
          tf=$(motion::setup.update 'vehicle.speak' 'MOTION_DETECTED_VEHICLE_SPEAK') && update=$((update+tf))
          tf=$(motion::setup.update 'vehicle.tune' 'MOTION_DETECTED_VEHICLE_TUNE') && update=$((update+tf))
          # detected.animal
          tf=$(motion::setup.update 'animal.entity' 'MOTION_DETECTED_ANIMAL_ENTITY') && update=$((update+tf))
          tf=$(motion::setup.update 'animal.ago' 'MOTION_DETECTED_ANIMAL_AGO') && update=$((update+tf))
          tf=$(motion::setup.update 'animal.deviation' 'MOTION_DETECTED_ANIMAL_DEVIATION') && update=$((update+tf))
          tf=$(motion::setup.update 'animal.notify' 'MOTION_DETECTED_ANIMAL_NOTIFY') && update=$((update+tf))
          tf=$(motion::setup.update 'animal.speak' 'MOTION_DETECTED_ANIMAL_SPEAK') && update=$((update+tf))
          tf=$(motion::setup.update 'animal.tune' 'MOTION_DETECTED_ANIMAL_TUNE') && update=$((update+tf))
          # detected.entity
          tf=$(motion::setup.update 'entity.name' 'MOTION_DETECT_ENTITY') && update=$((update+tf))
          tf=$(motion::setup.update 'entity.ago' 'MOTION_DETECTED_ENTITY_AGO') && update=$((update+tf))
          tf=$(motion::setup.update 'entity.deviation' 'MOTION_DETECTED_ENTITY_DEVIATION') && update=$((update+tf))
          tf=$(motion::setup.update 'entity.notify' 'MOTION_DETECTED_ENTITY_NOTIFY') && update=$((update+tf))
          tf=$(motion::setup.update 'entity.speak' 'MOTION_DETECTED_ENTITY_SPEAK') && update=$((update+tf))
          tf=$(motion::setup.update 'entity.tune' 'MOTION_DETECTED_ENTITY_TUNE') && update=$((update+tf))
        fi

        # test if update
        if [ ${update:-0} -gt 0 ]; then
          bashio::log.notice "Automatically rebuilding Lovelace and YAML"
          pushd /config &> /dev/null
          make tidy --silent &> /dev/null
          make --silent &> /dev/null
          popd &> /dev/null
          bashio::log.notice "Rebuild complete; restart Home Assistant"
        else
          bashio::log.notice "No rebuild required"
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
  fi
}


## start the apache server in FOREGROUND (does not exit)
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
  export MOTION_JSON_FILE=$(motion.config.file)
  export MOTION_SHARE_DIR=$(motion.config.share_dir)

  # pass environment
  echo 'PassEnv MOTION_JSON_FILE' >> "${conf}"
  echo 'PassEnv MOTION_SHARE_DIR' >> "${conf}"

  # make /run/apache2 for PID file
  mkdir -p /run/apache2

  # start HTTP daemon
  bashio::log.debug "Starting Apache: ${conf} ${host} ${port}"

  if [ "${foreground:-false}" = 'true' ]; then
    MOTION_JSON_FILE=$(motion.config.file) httpd -E ${MOTION_LOGTO} -e debug -f "${MOTION_APACHE_CONF}" -DFOREGROUND
  else
    MOTION_JSON_FILE=$(motion.config.file) httpd -E ${MOTION_LOGTO} -e debug -f "${MOTION_APACHE_CONF}"
  fi
}

process_config_camera_ftpd()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

process_config_camera_mjpeg()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

process_config_camera_http()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

process_config_camera_v4l2()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json='null'
  local value

  # set v4l2_pallette
  value=$(echo "${config:-null}" | jq -r ".v4l2_pallette")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=17; fi
  json=$(echo "${json}" | jq '.v4l2_palette='${value})
  sed -i "s/^v4l2_palette\s[0-9]\+/v4l2_palette ${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"v4l2_palette":'"${value}"
  bashio::log.debug "Set v4l2_palette to ${value}"

  # set brightness
  value=$(echo "${config:-null}" | jq -r ".v4l2_brightness")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/brightness=[0-9]\+/brightness=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"brightness":'"${value}"
  bashio::log.debug "Set brightness to ${value}"

  # set contrast
  value=$(jq -r ".v4l2_contrast" "${CONFIG_PATH}")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/contrast=[0-9]\+/contrast=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"contrast":'"${value}"
  bashio::log.debug "Set contrast to ${value}"

  # set saturation
  value=$(jq -r ".v4l2_saturation" "${CONFIG_PATH}")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/saturation=[0-9]\+/saturation=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"saturation":'"${value}"
  bashio::log.debug "Set saturation to ${value}"

  # set hue
  value=$(jq -r ".v4l2_hue" "${CONFIG_PATH}")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/hue=[0-9]\+/hue=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"hue":'"${value}"
  bashio::log.debug "Set hue to ${value}"

  echo "${json:-null}"
}

## cameras
process_config_cameras()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

## defaults
process_config_defaults()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

## mqtt
process_config_mqtt()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local result=
  local value
  local json

  # local json server (hassio addon)
  value=$(echo "${config}" | jq -r ".host")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value="core-mosquitto"; fi
  bashio::log.info "Using MQTT host: ${value}"
  json='{"host":"'"${value}"'"'

  # username
  value=$(echo "${config}" | jq -r ".username")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=""; fi
  bashio::log.info "Using MQTT username: ${value}"
  json="${json}"',"username":"'"${value}"'"'

  # password
  value=$(echo "${config}" | jq -r ".password")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=""; fi
  bashio::log.info "Using MQTT password: ${value}"
  json="${json}"',"password":"'"${value}"'"'

  # port
  value=$(echo "${config}" | jq -r ".port")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=1883; fi
  bashio::log.info "Using MQTT port: ${value}"
  json="${json}"',"port":'"${value}"'}'

  echo "${json:-null}"
}

## process configuration
process_config_system()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local timestamp=$(date -u +%FT%TZ)
  local ipaddr=$(ip addr | egrep -A4 UP | egrep 'inet ' | egrep -v 'scope host lo' | egrep -v 'scope global docker' | awk '{ print $2 }')
  local json='{"ipaddr":"'${ipaddr%%/*}'","hostname":"'$(hostname)'","arch":"'$(arch)'","date":'$(date -u +%s)',"timestamp":"'${timestamp}'"}'

  echo "${json:-null}"
}

## process configuration
process_config_motion()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local path=${1}
  local json

  json=$(echo "${json:-null}" | jq '.+='$(process_config_system ${path}))
  json=$(echo "${json:-null}" | jq '.+='$(process_config_mqtt ${path}))
  json=$(echo "${json:-null}" | jq '.+='$(process_config_defaults ${path}))
  json=$(echo "${json:-null}" | jq '.+='$(process_config_cameras ${path}))

  echo "${json:-null}"
}

start_motion()
{
  bashio::log.trace "${FUNCNAME[0]}" "${*}"

  local path=${1}
  local json

  json=$(process_config_motion ${path})

  echo "${json:-null}"
}

###
### START
###

## get IP address
ipaddr=$(ip addr | egrep -A4 UP | egrep 'inet ' | egrep -v 'scope host lo' | egrep -v 'scope global docker' | awk '{ print $2 }')
ipaddr=${ipaddr%%/*}

## add-on API
ADDON_API="http://${ipaddr}:${MOTION_APACHE_PORT}"

## build internal configuration
JSON='{"config_path":"'"${CONFIG_PATH}"'","ipaddr":"'${ipaddr}'","hostname":"'"$(hostname)"'","arch":"'$(arch)'","date":'$(date -u +%s)

# device name
VALUE=$(jq -r ".device" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE="$(hostname -s)"
  bashio::log.warning "device unspecified; setting device: ${VALUE}"
fi
JSON="${JSON}"',"device":"'"${VALUE}"'"'
bashio::log.info "MOTION_DEVICE: ${VALUE}"
MOTION_DEVICE="${VALUE}"

# device group
VALUE=$(jq -r ".group" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE="motion"
  bashio::log.warning "group unspecified; setting group: ${VALUE}"
fi
JSON="${JSON}"',"group":"'"${VALUE}"'"'
bashio::log.info "MOTION_GROUP: ${VALUE}"
MOTION_GROUP="${VALUE}"

# client
VALUE=$(jq -r ".client" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE="+"
  bashio::log.warning "client unspecified; setting client: ${VALUE}"
fi
JSON="${JSON}"',"client":"'"${VALUE}"'"'
bashio::log.info "MOTION_CLIENT: ${VALUE}"
MOTION_CLIENT="${VALUE}"

## time zone
VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then
  VALUE="GMT"
  bashio::log.warning "timezone unspecified; defaulting to ${VALUE}"
else
  bashio::log.info "TIMEZONE: ${VALUE}"
fi
if [ -s "/usr/share/zoneinfo/${VALUE}" ]; then
  cp /usr/share/zoneinfo/${VALUE} /etc/localtime
  echo "${VALUE}" > /etc/timezone
else
  bashio::log.error "No known timezone: ${VALUE}"
fi
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

# set unit_system for events
VALUE=$(jq -r '.unit_system' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="imperial"; fi
bashio::log.debug "Set unit_system to ${VALUE}"
JSON="${JSON}"',"unit_system":"'"${VALUE}"'"'

# set latitude for events
VALUE=$(jq -r '.latitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
bashio::log.debug "Set latitude to ${VALUE}"
JSON="${JSON}"',"latitude":'"${VALUE}"

# set longitude for events
VALUE=$(jq -r '.longitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
bashio::log.debug "Set longitude to ${VALUE}"
JSON="${JSON}"',"longitude":'"${VALUE}"

# set elevation for events
VALUE=$(jq -r '.elevation' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
bashio::log.debug "Set elevation to ${VALUE}"
JSON="${JSON}"',"elevation":'"${VALUE}"

# set format for events
VALUE=$(jq -r '.format' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE='gif'; fi
bashio::log.debug "Set format to ${VALUE}"
JSON="${JSON}"',"format":"'"${VALUE}"'"'

##
## MQTT
##

# local MQTT server (hassio addon)
VALUE=$(jq -r ".mqtt.host" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="mqtt"; fi
bashio::log.info "Using MQTT at ${VALUE}"
MQTT='{"host":"'"${VALUE}"'"'
# username
VALUE=$(jq -r ".mqtt.username" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
bashio::log.info "Using MQTT username: ${VALUE}"
MQTT="${MQTT}"',"username":"'"${VALUE}"'"'
# password
VALUE=$(jq -r ".mqtt.password" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
bashio::log.info "Using MQTT password: ${VALUE}"
MQTT="${MQTT}"',"password":"'"${VALUE}"'"'
# port
VALUE=$(jq -r ".mqtt.port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
bashio::log.info "Using MQTT port: ${VALUE}"
MQTT="${MQTT}"',"port":'"${VALUE}"'}'

## finish
JSON="${JSON}"',"mqtt":'"${MQTT}"

###
## WATSON
###

if [ -n "${WATSON:-}" ]; then
  JSON="${JSON}"',"watson":'"${WATSON}"
else
  bashio::log.debug "Watson Visual Recognition not specified"
  JSON="${JSON}"',"watson":null'
fi

###
## DIGITS
###

if [ -n "${DIGITS:-}" ]; then
  JSON="${JSON}"',"digits":'"${DIGITS}"
else
  bashio::log.debug "DIGITS not specified"
  JSON="${JSON}"',"digits":null'
fi

###
### MOTION
###

MOTION='{'

# set log_type (FIRST ENTRY)
VALUE=$(jq -r ".log_motion_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="ALL"; fi
sed -i "s|^log_type .*|log_type ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"'"log_type":"'"${VALUE}"'"'
bashio::log.debug "Set motion.log_type to ${VALUE}"

# set log_level
VALUE=$(jq -r ".log_motion_level" "${CONFIG_PATH}")
case ${VALUE} in
  emergency)
    VALUE=1
    ;;
  alert)
    VALUE=2
    ;;
  critical)
    VALUE=3
    ;;
  error)
    VALUE=4
    ;;
  warn)
    VALUE=5
    ;;
  info)
    VALUE=7
    ;;
  debug)
    VALUE=8
    ;;
  all)
    VALUE=9
    ;;
  *|notice)
    VALUE=6
    ;;
esac
sed -i "s/^log_level .*/log_level ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_level":'"${VALUE}"
bashio::log.debug "Set motion.log_level to ${VALUE}"

# set log_file
VALUE=$(jq -r ".log_file" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/tmp/motion.log"; fi
sed -i "s|^log_file .*|log_file ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_file":"'"${VALUE}"'"'
bashio::log.debug "Set log_file to ${VALUE}"
export MOTION_LOGTO=${VALUE}

# shared directory for results (not images and JSON)
VALUE=$(jq -r ".share_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/share/${MOTION_GROUP}"; fi
bashio::log.debug "Set share_dir to ${VALUE}"
JSON="${JSON}"',"share_dir":"'"${VALUE}"'"'
export MOTION_SHARE_DIR="${VALUE}"

# base target_dir
VALUE=$(jq -r ".default.target_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_APACHE_HTDOCS}/cameras"; fi
bashio::log.debug "Set target_dir to ${VALUE}"
sed -i "s|^target_dir .*|target_dir ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"target_dir":"'"${VALUE}"'"'
export MOTION_TARGET_DIR="${VALUE}"

# set auto_brightness
VALUE=$(jq -r ".default.auto_brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/^auto_brightness .*/auto_brightness ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"auto_brightness":"'"${VALUE}"'"'
bashio::log.debug "Set auto_brightness to ${VALUE}"

# set locate_motion_mode
VALUE=$(jq -r ".default.locate_motion_mode" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
sed -i "s/^locate_motion_mode .*/locate_motion_mode ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_mode":"'"${VALUE}"'"'
bashio::log.debug "Set locate_motion_mode to ${VALUE}"

# set locate_motion_style (box, redbox, cross, redcross)
VALUE=$(jq -r ".default.locate_motion_style" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="box"; fi
sed -i "s/^locate_motion_style .*/locate_motion_style ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_style":"'"${VALUE}"'"'
bashio::log.debug "Set locate_motion_style to ${VALUE}"

# set post_pictures; enumerated [on,center,first,last,best,most]
VALUE=$(jq -r '.default.post_pictures' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="best"; fi
bashio::log.debug "Set post_pictures to ${VALUE}"
MOTION="${MOTION}"',"post_pictures":"'"${VALUE}"'"'
export MOTION_POST_PICTURES="${VALUE}"

# set picture_output (on, off, first, best)
case "${MOTION_POST_PICTURES}" in
  'on'|'center'|'most')
    SPEC="on"
    bashio::log.debug "process all images; picture_output: ${SPEC}"
  ;;
  'best'|'first')
    SPEC="${MOTION_POST_PICTURES}"
    bashio::log.debug "process one image; picture_output: ${SPEC}"
  ;;
  'off')
    SPEC="off"
    bashio::log.debug "process no image; picture_output: ${SPEC}"
  ;;
esac

# check specified for over-ride
VALUE=$(jq -r ".default.picture_output" "${CONFIG_PATH}")
if [ "${VALUE:-}" != 'null' ] && [ ! -z "${VALUE:-}" ]; then
  if [ "${VALUE}" != "${SPEC}" ]; then
    bashio::log.warning "picture_output; specified ${VALUE} does not match expected: ${SPEC}"
  else
    bashio::log.debug "picture_output; specified ${VALUE} matches expected: ${SPEC}"
  fi
else
  VALUE="${SPEC}"
  bashio::log.debug "picture_output; unspecified; using: ${VALUE}"
fi
sed -i "s/^picture_output .*/picture_output ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_output":"'"${VALUE}"'"'
bashio::log.debug "Set picture_output to ${VALUE}"
PICTURE_OUTPUT=${VALUE}

# set movie_output (on, off)
if [ "${PICTURE_OUTPUT:-}" = 'best' ] || [ "${PICTURE_OUTPUT:-}" = 'first' ]; then
  bashio::log.debug "Picture output: ${PICTURE_OUTPUT}; setting movie_output: on"
  VALUE='on'
else
  VALUE=$(jq -r '.default.movie_output' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then
    bashio::log.debug "movie_output unspecified; defaulting: off"
    VALUE="off"
  else
    case ${VALUE} in
      '3gp')
        bashio::log.warning "movie_output: video type ${VALUE}; ensure camera type: ftpd"
        MOTION_VIDEO_CODEC="${VALUE}"
        VALUE='off'
      ;;
      'on'|'mp4')
        bashio::log.debug "movie_output: supported codec: ${VALUE}; - MPEG-4 Part 14 H264 encoding"
        MOTION_VIDEO_CODEC="${VALUE}"
        VALUE='on'
      ;;
      'mpeg4'|'swf'|'flv'|'ffv1'|'mov'|'mkv'|'hevc')
        bashio::log.warning "movie_output: unsupported option: ${VALUE}"
        MOTION_VIDEO_CODEC="${VALUE}"
        VALUE='on'
      ;;
      'off')
        bashio::log.debug "movie_output: off defined"
        MOTION_VIDEO_CODEC=
        VALUE='off'
      ;;
      '*')
        bashio::log.error "movie_output: unknown option for movie_output: ${VALUE}"
        MOTION_VIDEO_CODEC=
        VALUE='off'
      ;;
    esac
  fi
fi
sed -i "s/^movie_output .*/movie_output ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"movie_output":"'"${VALUE}"'"'
bashio::log.debug "Set movie_output to ${VALUE}"
if [ "${VALUE:-null}" != 'null' ]; then
  sed -i "s/^movie_output_motion .*/movie_output_motion ${VALUE}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"movie_output_motion":"'"${VALUE}"'"'
  bashio::log.debug "Set movie_output_motion to ${VALUE}"
fi

# set picture_type (jpeg, ppm)
VALUE=$(jq -r ".default.picture_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="jpeg"; fi
sed -i "s/^picture_type .*/picture_type ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_type":"'"${VALUE}"'"'
bashio::log.debug "Set picture_type to ${VALUE}"

# set netcam_keepalive (off,force,on)
VALUE=$(jq -r ".default.netcam_keepalive" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/^netcam_keepalive .*/netcam_keepalive ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"netcam_keepalive":"'"${VALUE}"'"'
bashio::log.debug "Set netcam_keepalive to ${VALUE}"

# set netcam_userpass
VALUE=$(jq -r ".default.netcam_userpass" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
sed -i "s/^netcam_userpass .*/netcam_userpass ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"netcam_userpass":"'"${VALUE}"'"'
bashio::log.debug "Set netcam_userpass to ${VALUE}"

## numeric values

# set v4l2_palette
VALUE=$(jq -r ".default.palette" "${CONFIG_PATH}")
if [ "${VALUE:-}" = "null" ]; then VALUE=17; fi
sed -i "s/^v4l2_palette .*/v4l2_palette ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"palette":'"${VALUE}"
bashio::log.debug "Set palette to ${VALUE}"

# set pre_capture
VALUE=$(jq -r ".default.pre_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/^pre_capture .*/pre_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"pre_capture":'"${VALUE}"
bashio::log.debug "Set pre_capture to ${VALUE}"

# set post_capture
VALUE=$(jq -r ".default.post_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/^post_capture .*/post_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"post_capture":'"${VALUE}"
bashio::log.debug "Set post_capture to ${VALUE}"

# set event_gap
VALUE=$(jq -r ".default.event_gap" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=15; fi
sed -i "s/^event_gap .*/event_gap ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"event_gap":'"${VALUE}"
bashio::log.debug "Set event_gap to ${VALUE}"

# set fov
VALUE=$(jq -r ".default.fov" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=60; fi
MOTION="${MOTION}"',"fov":'"${VALUE}"
bashio::log.debug "Set fov to ${VALUE}"

# set minimum_motion_frames
VALUE=$(jq -r ".default.minimum_motion_frames" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=10; fi
sed -i "s/^minimum_motion_frames .*/minimum_motion_frames ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_motion_frames":'"${VALUE}"
bashio::log.debug "Set minimum_motion_frames to ${VALUE}"

# set quality
VALUE=$(jq -r ".default.picture_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=50; fi
sed -i "s/^picture_quality .*/picture_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_quality":'"${VALUE}"
bashio::log.debug "Set picture_quality to ${VALUE}"

# set framerate
VALUE=$(jq -r ".default.framerate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=2; fi
sed -i "s/^framerate .*/framerate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"framerate":'"${VALUE}"
bashio::log.debug "Set framerate to ${VALUE}"
FRAMERATE=${VALUE}

# set stream_maxrate
VALUE=$(jq -r ".default.stream_maxrate" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = "null" ] || [ ${VALUE} -eq 0 ]; then VALUE=${FRAMERATE}; fi
bashio::log.debug "Set stream_maxrate to ${VALUE}"
sed -i "s/^stream_maxrate .*/stream_maxrate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_maxrate":'"${VALUE}"

# set stream_motion
VALUE=$(jq -r ".default.stream_motion" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE='on'; fi
sed -i "s/^stream_motion .*/stream_motion ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_motion":"'"${VALUE}"'"'
bashio::log.debug "Set stream_motion to ${VALUE}"

# set text_changes
VALUE=$(jq -r ".default.changes" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE='off'; fi
sed -i "s/^text_changes .*/text_changes ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"changes":"'"${VALUE}"'"'
bashio::log.debug "Set text_changes to ${VALUE}"

# set text_scale
VALUE=$(jq -r ".default.text_scale" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1; fi
sed -i "s/^text_scale .*/text_scale ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"text_scale":'"${VALUE}"
bashio::log.debug "Set text_scale to ${VALUE}"

# set despeckle_filter
VALUE=$(jq -r ".default.despeckle" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE='EedDl'; fi
sed -i "s/^despeckle_filter .*/despeckle_filter ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"despeckle_filter":"'"${VALUE}"'"'
bashio::log.debug "Set despeckle_filter to ${VALUE}"

## vid_control_params

## ps3eye
# ---------Controls---------
#   V4L2 ID   Name and Range
# ID09963776 Brightness, 0 to 255
# ID09963777 Contrast, 0 to 255
# ID09963778 Saturation, 0 to 255
# ID09963779 Hue, -90 to 90
# ID09963788 White Balance, Automatic, 0 to 1
# ID09963793 Exposure, 0 to 255
# ID09963794 Gain, Automatic, 0 to 1
# ID09963795 Gain, 0 to 63
# ID09963796 Horizontal Flip, 0 to 1
# ID09963797 Vertical Flip, 0 to 1
# ID09963800 Power Line Frequency, 0 to 1
#   menu item: Value 0 Disabled
#   menu item: Value 1 50 Hz
# ID09963803 Sharpness, 0 to 63
# ID10094849 Auto Exposure, 0 to 1
#   menu item: Value 0 Auto Mode
#   menu item: Value 1 Manual Mode
# --------------------------

# set brightness
VALUE=$(jq -r ".default.brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/brightness=[0-9]\+/brightness=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"brightness":'"${VALUE}"
bashio::log.debug "Set brightness to ${VALUE}"

# set contrast
VALUE=$(jq -r ".default.contrast" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/contrast=[0-9]\+/contrast=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"contrast":'"${VALUE}"
bashio::log.debug "Set contrast to ${VALUE}"

# set saturation
VALUE=$(jq -r ".default.saturation" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/saturation=[0-9]\+/saturation=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"saturation":'"${VALUE}"
bashio::log.debug "Set saturation to ${VALUE}"

# set hue
VALUE=$(jq -r ".default.hue" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/hue=[0-9]\+/hue=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"hue":'"${VALUE}"
bashio::log.debug "Set hue to ${VALUE}"

## other

# set rotate
VALUE=$(jq -r ".default.rotate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
bashio::log.debug "Set rotate to ${VALUE}"
sed -i "s/^rotate .*/rotate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"rotate":'"${VALUE}"

# set webcontrol_parms
VALUE=$(jq -r ".default.webcontrol_parms" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1; fi
bashio::log.debug "Set webcontrol_parms to ${VALUE}"
sed -i "s/^webcontrol_parms .*/webcontrol_parms ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"webcontrol_parms":'"${VALUE}"

# set webcontrol_port
VALUE=$(jq -r ".default.webcontrol_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
bashio::log.debug "Set webcontrol_port to ${VALUE}"
sed -i "s/^webcontrol_port .*/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"webcontrol_port":'"${VALUE}"

# set stream_port
VALUE=$(jq -r ".default.stream_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; fi
bashio::log.debug "Set stream_port to ${VALUE}"
sed -i "s/^stream_port .*/stream_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_port":'"${VALUE}"
MOTION_STREAM_PORT=${VALUE}

# set stream_quality
VALUE=$(jq -r ".default.stream_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=50; fi
bashio::log.debug "Set stream_quality to ${VALUE}"
sed -i "s/^stream_quality .*/stream_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_quality":'"${VALUE}"

# set width
VALUE=$(jq -r ".default.width" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=640; fi
sed -i "s/^width .*/width ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"width":'"${VALUE}"
WIDTH=${VALUE}
bashio::log.debug "Set width to ${VALUE}"

# set height
VALUE=$(jq -r ".default.height" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=480; fi
sed -i "s/^height .*/height ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"height":'"${VALUE}"
HEIGHT=${VALUE}
bashio::log.debug "Set height to ${VALUE}"

## THRESHOLD

VALUE=$(jq -r ".default.threshold" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = 'null' ] || [ ${VALUE:-0} -le 0 ]; then
  VALUE=$(jq -r ".default.threshold_percent" "${CONFIG_PATH}")
  if [ "${VALUE:-null}" != 'null' ] && [ ${VALUE:-0} -gt 0 ]; then
    PCT=${VALUE}
    VALUE=$(echo "${PCT} * ( ${WIDTH} * ${HEIGHT} ) / 100.0" | bc -l) && VALUE=${VALUE%%.*}
  else
    VALUE=1000
  fi
fi
if [ "${PCT:-null}" = 'null' ]; then
  PCT=$(echo "${VALUE} / ( ${WIDTH} * ${HEIGHT} ) * 100.0" | bc -l) && PCT=${PCT%%.*}
  PCT=${PCT:-null}
fi

bashio::log.debug "Set threshold_percent to ${PCT:-null}"
MOTION="${MOTION}"',"threshold_percent":'"${PCT:-null}"
bashio::log.debug "Set threshold to ${VALUE}"
sed -i "s/^threshold .*/threshold ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold":'"${VALUE:-null}"

# set threshold_maximum
VALUE=$(jq -r ".default.threshold_maximum" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = "null" ]; then VALUE=0; fi
bashio::log.debug "Set threshold_maximum to ${VALUE}"
sed -i "s/^threshold_maximum .*/threshold_maximum ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold_maximum":'"${VALUE:-0}"

# set threshold_tune (on/off)
VALUE=$(jq -r ".default.threshold_tune" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = 'null' ]; then VALUE='on'; fi
bashio::log.debug "Set threshold_tune to ${VALUE}"
sed -i "s/^threshold_tune .*/threshold_tune ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold_tune":"'"${VALUE}"'"'

# set lightswitch percent
VALUE=$(jq -r ".default.lightswitch_percent" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = "null" ]; then VALUE=0; fi
bashio::log.debug "Set lightswitch percent to ${VALUE}"
sed -i "s/^lightswitch_percent .*/lightswitch_percent ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"lightswitch_percent":'"${VALUE:-null}"

# set lightswitch frames
VALUE=$(jq -r ".default.lightswitch_frames" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = "null" ]; then VALUE=5; fi
bashio::log.debug "Set lightswitch frames to ${VALUE}"
sed -i "s/^lightswitch_frames .*/lightswitch_frames ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"lightswitch_frames":'"${VALUE}"

# set movie_max_time
VALUE=$(jq -r ".default.movie_max_time" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = "null" ]; then VALUE="15"; fi
bashio::log.debug "Set movie_max_time to ${VALUE}"
sed -i "s/^movie_max_time .*/movie_max_time ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"movie_max_time":'"${VALUE:-30}"

# set interval for events
VALUE=$(jq -r '.default.interval' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${EVENT_GAP:-15}; fi
bashio::log.debug "Set interval to ${VALUE}"
MOTION="${MOTION}"',"interval":'${VALUE}

# set type
VALUE=$(jq -r '.default.type' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="netcam"; fi
bashio::log.debug "Set type to ${VALUE}"
MOTION="${MOTION}"',"type":"'"${VALUE}"'"'

## ALL CAMERAS SHARE THE SAME USERNAME:PASSWORD CREDENTIALS

# set username and password
USERNAME=$(jq -r ".default.username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".default.password" "${CONFIG_PATH}")
if [ "${USERNAME}" != "null" ] && [ "${PASSWORD}" != "null" ] && [ ! -z "${USERNAME}" ] && [ ! -z "${PASSWORD}" ]; then
  bashio::log.debug "Set authentication to Basic for both stream and webcontrol"
  sed -i "s/^stream_auth_method .*/stream_auth_method 1/" "${MOTION_CONF}"
  sed -i "s/^stream_authentication .*/stream_authentication ${USERNAME}:${PASSWORD}/" "${MOTION_CONF}"
  sed -i "s/^webcontrol_authentication .*/webcontrol_authentication ${USERNAME}:${PASSWORD}/" "${MOTION_CONF}"
  bashio::log.debug "Enable access for any host"
  sed -i "s/^stream_localhost .*/stream_localhost off/" "${MOTION_CONF}"
  sed -i "s/^webcontrol_localhost .*/webcontrol_localhost off/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"stream_auth_method":"Basic"'
else
  bashio::log.debug "WARNING: no username and password; stream and webcontrol limited to localhost only"
  sed -i "s/^stream_localhost .*/stream_localhost on/" "${MOTION_CONF}"
  sed -i "s/^webcontrol_localhost .*/webcontrol_localhost on/" "${MOTION_CONF}"
fi

# add username and password to configuration
MOTION="${MOTION}"',"username":"'"${USERNAME}"'"'
MOTION="${MOTION}"',"password":"'"${PASSWORD}"'"'

## end motion structure; cameras section depends on well-formed JSON for $MOTION
MOTION="${MOTION}"'}'

## append to configuration JSON
JSON="${JSON}"',"motion":'"${MOTION}"

bashio::log.debug "MOTION: ${MOTION}"

###
### process cameras
###

ncamera=$(jq '.cameras|length' "${CONFIG_PATH}")
bashio::log.info "Processing ${ncamera:-0} cameras..."

MOTION_COUNT=0
CNUM=0

##
## LOOP THROUGH ALL CAMERAS
##

for (( i=0; i < ncamera; i++)); do

  bashio::log.debug "+++ CAMERA ${i}"

  ## TOP-LEVEL
  if [ -z "${CAMERAS:-}" ]; then CAMERAS='['; else CAMERAS="${CAMERAS}"','; fi
  bashio::log.debug "CAMERA #: $i"
  CAMERAS="${CAMERAS}"'{"id":'${i}

  # process camera type
  VALUE=$(jq -r '.cameras['${i}'].type' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then
    VALUE=$(jq -r '.default.type' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="netcam"; fi
  fi
  CAMERA_TYPE="${VALUE}"
  bashio::log.debug "Set type to ${VALUE}"
  CAMERAS="${CAMERAS}"',"type":"'"${VALUE}"'"'

  # name
  VALUE=$(jq -r '.cameras['${i}'].name' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="camera-name${i}"; fi
  bashio::log.debug "Set name to ${VALUE}"
  CAMERAS="${CAMERAS}"',"name":"'"${VALUE}"'"'
  CNAME=${VALUE}

  # icon
  VALUE=$(jq -r '.cameras['${i}'].icon' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then VALUE='cctv'; fi
  bashio::log.debug "Set icon to ${VALUE}"
  CAMERAS="${CAMERAS}"',"icon":"'"${VALUE}"'"'

  # What3Words (w3w)
  w3w=""

  # words
  VALUE=$(jq -r '.cameras['${i}'].words' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" != 'null' ]; then
    VALUE=${VALUE#///*} 
    a=${VALUE%%.*}
    c=${VALUE##*.}
    b=${VALUE#*.}
    b=${b%%.*}
    w3w='["'${a}'","'${b}'","'${c}'"]'
    bashio::log.debug "Camera: ${CNAME}: converted ${w3w} from ${VALUE}"
  fi

  # w3w (array)
  VALUE=$(jq '.cameras['${i}'].w3w?' "${CONFIG_PATH}")
  if [ -z "${w3w:-}" ] && [ "${VALUE:-null}" = 'null' ]; then
    bashio::log.info "What3Words not specified; camera: ${CNAME}"
    w3w='["","",""]'
  else
    if [ "${VALUE:-null}" != 'null' ]; then
      if [ ! -z "${w3w:-}" ]; then
        bashio::log.info "What3Words: both words and w3w specified; using w3w; camera: ${CNAME}"
      fi
      w3w="${VALUE}"
    fi
  fi
  CAMERAS="${CAMERAS}"',"w3w":'"${w3w}"
  bashio::log.debug "Set w3w to ${w3w}"

  # icon top
  VALUE=$(jq -r '.cameras['${i}'].top' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then
    VALUE=${ICON_TOP:-10}
    ICON_TOP=$((VALUE+5))
    if [ ${ICON_TOP} -ge 95 ]; then
      ICON_TOP=10;
      ICON_LEFT=${ICON_LEFT:-10} && ICON_LEFT=$((ICON_LEFT+5))
    fi
  fi
  bashio::log.debug "Set top to ${VALUE}"
  CAMERAS="${CAMERAS}"',"top":'"${VALUE}"

  # icon left
  VALUE=$(jq -r '.cameras['${i}'].left' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then VALUE=${ICON_LEFT:-10}; fi
  bashio::log.debug "Set left to ${VALUE}"
  CAMERAS="${CAMERAS}"',"left":'"${VALUE}"

  # process models string to array of strings
  VALUE=$(jq -r '.cameras['${i}'].models' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then
    W=$(echo "${WATSON:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"wvr:\1"\2/g' | fmt -1000)
    # bashio::log.debug "WATSON: ${WATSON} ${W}"
    D=$(echo "${DIGITS:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"digits:\1"\2/g' | fmt -1000)
    # bashio::log.debug "DIGITS: ${DIGITS} ${D}"
    VALUE=$(echo ${W} ${D})
    VALUE=$(echo "${VALUE}" | sed 's/ /,/g')
  else
    VALUE=$(echo "${VALUE}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
  fi
  bashio::log.debug "Set models to ${VALUE}"
  CAMERAS="${CAMERAS}"',"models":['"${VALUE}"']'

  # process camera fov; WCV80n is 61.5 (62); 56 or 75 degrees for PS3 Eye camera
  VALUE=$(jq -r '.cameras['${i}'].fov' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [ ${VALUE} -lt 1 ]; then VALUE=$(echo "${MOTION}" | jq -r '.fov'); fi
  bashio::log.debug "Set fov to ${VALUE}"
  CAMERAS="${CAMERAS}"',"fov":'"${VALUE}"

  # width
  VALUE=$(jq -r '.cameras['${i}'].width' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.width'); fi
  CAMERAS="${CAMERAS}"',"width":'"${VALUE}"
  bashio::log.debug "Set width to ${VALUE}"
  WIDTH=${VALUE}

  # height
  VALUE=$(jq -r '.cameras['${i}'].height' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.height'); fi
  CAMERAS="${CAMERAS}"',"height":'"${VALUE}"
  bashio::log.debug "Set height to ${VALUE}"
  HEIGHT=${VALUE}

  # movie_max_time
  VALUE=$(jq -r '.cameras['${i}'].movie_max_time' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.movie_max_time') && VALUE=${VALUE:-30}; fi
  CAMERAS="${CAMERAS}"',"movie_max_time":'"${VALUE}"
  bashio::log.debug "Set movie_max_time to ${VALUE}"
  MOVIE_MAX_TIME=${VALUE}

  # framerate
  VALUE=$(jq -r '.cameras['${i}'].framerate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then
    VALUE=$(jq -r '.framerate' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=$(echo "${MOTION}" | jq -r '.framerate') && VALUE=${VALUE:-5}; fi
  fi
  bashio::log.debug "Set framerate to ${VALUE}"
  CAMERAS="${CAMERAS}"',"framerate":'"${VALUE}"
  FRAMERATE=${VALUE}

  # stream_maxrate
  VALUE=$(jq -r '.cameras['${i}'].stream_maxrate' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = "null" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_maxrate'); fi
  if [ "${VALUE:-null}" = "null" ]; then VALUE=${FRAMERATE}; fi
  CAMERAS="${CAMERAS}"',"stream_maxrate":'"${VALUE}"
  bashio::log.debug "Set stream_maxrate to ${VALUE}"
  STREAM_MAXRATE=${VALUE}

  # stream_motion
  VALUE=$(jq -r '.cameras['${i}'].stream_motion' "${CONFIG_PATH}")
  if [ "${VALUE}" = "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_motion') && VALUE=${VALUE:-off}; fi
  bashio::log.debug "Set stream_motion to ${VALUE}"
  CAMERAS="${CAMERAS}"',"stream_motion":"'"${VALUE}"'"'
  STREAM_MOTION=${VALUE}

  # process camera event_gap; set on wcv80n web GUI; default 6
  VALUE=$(jq -r '.cameras['${i}'].event_gap' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then
    VALUE=$(jq -r '.event_gap' "${CONFIG_PATH}")
    if [ "${VALUE:-null}" = "null" ] || [ ${VALUE:-0} -lt 1 ]; then VALUE=$(echo "${MOTION}" | jq -r '.event_gap') && VALUE=${VALUE:-15}; fi
  fi
  bashio::log.debug "Set event_gap to ${VALUE}"
  CAMERAS="${CAMERAS}"',"event_gap":'"${VALUE}"
  EVENT_GAP=${VALUE}

  # target_dir
  VALUE=$(jq -r '.cameras['${i}'].target_dir' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_TARGET_DIR}/${CNAME}"; fi
  bashio::log.debug "Set target_dir to ${VALUE}"
  if [ ! -d "${VALUE}" ]; then mkdir -p "${VALUE}"; fi
  CAMERAS="${CAMERAS}"',"target_dir":"'"${VALUE}"'"'
  TARGET_DIR="${VALUE}"

  # username for mjpeg camera is username iff specified
  VALUE=$(jq -r '.cameras['${i}'].username' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then
    # username is same as netcam_userpass iff specified
    VALUE=$(jq -r '.cameras['${i}'].netcam_userpass' "${CONFIG_PATH}")
    if [ "${VALUE:-null}" != 'null' ]; then
      # username from netcam_userpass
      VALUE=${VALUE%%:*}
    fi
    if [ "${VALUE:-null}" = 'null' ]; then
      # username is default
      VALUE=$(echo "${MOTION}" | jq -r '.username')
    fi
    USERNAME=${VALUE}
  fi
  bashio::log.debug "Set username to ${USERNAME}"
  CAMERAS="${CAMERAS}"',"username":"'"${USERNAME}"'"'

  # password for mjpeg camera is password iff specified
  VALUE=$(jq -r '.cameras['${i}'].password' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then
    # password is same as netcam_userpass iff specified
    VALUE=$(jq -r '.cameras['${i}'].netcam_userpass' "${CONFIG_PATH}")
    if [ "${VALUE:-null}" != 'null' ]; then
      # password from netcam_userpass
      VALUE=${VALUE##*:}
    fi
    if [ "${VALUE:-null}" = 'null' ]; then
      # password is default
      VALUE=$(echo "${MOTION}" | jq -r '.password')
    fi 
    PASSWORD=${VALUE}
  fi
  bashio::log.debug "Set username to ${PASSWORD}"
  CAMERAS="${CAMERAS}"',"password":"'"${PASSWORD}"'"'


  # CAMERA_TYPE
  case "${CAMERA_TYPE}" in
    local|netcam)
        bashio::log.debug "Camera: ${CNAME}; number: ${CNUM}; type: ${CAMERA_TYPE}"
        CAMERAS="${CAMERAS}"',"type":"'"${CAMERA_TYPE}"'"'
	;;
    ftpd|mqtt)
        # live
        VALUE=$(jq -r '.cameras['${i}'].mjpeg_url' "${CONFIG_PATH}")
        if [ "${VALUE:-null}" = 'null' ]; then
          VALUE=$(jq -r '.cameras['${i}'].netcam_url' "${CONFIG_PATH}")
          if [ "${VALUE}" != "null" ] || [ ! -z "${VALUE}" ]; then
            VALUE=$(echo "${VALUE}" | sed 's|mjpeg://|http://|')
            CAMERAS="${CAMERAS}"',"netcam_url":"'"${VALUE}"'"'
	  else
            bashio::log.warning "Camera: ${CNAME}; both mjpeg_url and netcam_url are undefined; no live stream"
	    VALUE=''
          fi
        fi
        bashio::log.debug "Set mjpeg_url to ${VALUE}"
        CAMERAS="${CAMERAS}"',"mjpeg_url":"'"${VALUE}"'"'
        url=${VALUE}

        # netcam
        VALUE=$(jq -r '.cameras['${i}'].netcam_url' "${CONFIG_PATH}")
        if [ ! -z "${VALUE:-}" ] && [ "${VALUE:-null}" != 'null' ]; then
          # network camera
          CAMERAS="${CAMERAS}"',"netcam_url":"'"${VALUE}"'"'
          bashio::log.debug "Set netcam_url to ${VALUE}"
          netcam_url=${VALUE}

          # userpass
          VALUE=$(jq -r '.cameras['${i}'].netcam_userpass' "${CONFIG_PATH}")
          if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_userpass'); fi
          CAMERAS="${CAMERAS}"',"netcam_userpass":"'"${VALUE}"'"'
          bashio::log.debug "Set netcam_userpass to ${VALUE}"
          netcam_userpass=${VALUE}

          # test netcam_url
          alive=$(curl --anyauth -fsqL -w '%{http_code}' --connect-timeout 2 --retry-connrefused --retry 10 --retry-max-time 2 --max-time 15 -u "${netcam_userpass:-null}" "${netcam_url:-null}" -o /dev/null 2> /dev/null || true)
          bashio::log.info "TEST: camera: ${CNAME}; type: ${CAMERA_TYPE}; response: ${alive:-null}; URL: ${netcam_url:-null}"
          CAMERAS="${CAMERAS}"',"response":"'"${alive}"'"'

          if [ "${alive:-}" != '200' ]; then
            bashio::log.debug "BAD: ${alive:-null}; camera: ${CNAME}; URL: ${netcam_url:-null}; userpass: ${netcam_userpass:-null}"
          else
            bashio::log.debug "GOOD: ${alive:-null}; camera: ${CNAME}; URL: ${netcam_url:-null}; userpass: ${netcam_userpass:-null}"
          fi
        fi

        # addon_api (uses ${url} from above)
        VALUE=$(jq -r '.cameras['${i}'].addon_api' "${CONFIG_PATH}")
        if [ "${CAMERA_TYPE}" != 'ftpd' ]; then
          if [ "${VALUE:-null}" = 'null' ]; then
            api="${url##*//}" && api=${api%%/*} && api=${api%%:*} && api="http://${api}:${MOTION_APACHE_PORT}"
          else
            api=${VALUE}
          fi
        else
          if [ "${VALUE:-null}" = 'null' ]; then
            api=${ADDON_API}
          else
            api=${VALUE}
          fi
        fi
        CAMERAS="${CAMERAS}"',"addon_api":"'${api}'"'

        # FTP share_dir
        if [ "${CAMERA_TYPE}" == 'ftpd' ]; then
          VALUE="${MOTION_SHARE_DIR%/*}/ftp/${CNAME}"
          bashio::log.debug "Set share_dir to ${VALUE}"
          CAMERAS="${CAMERAS}"',"share_dir":"'"${VALUE}"'"'
        fi

        bashio::log.debug "Camera: ${CNAME}; number: ${CNUM}; type: ${CAMERA_TYPE}"
        CAMERAS="${CAMERAS}"',"type":"'"${CAMERA_TYPE}"'"'

        # complete
        CAMERAS="${CAMERAS}"'}'
        continue
	;;
    *)
        bashio::log.error "CAMERA: ${CNAME}; number: ${CNUM}; invalid camera type: ${CAMERA_TYPE}; setting to unknown; skipping"
        CAMERA_TYPE="unknown"
        CAMERAS="${CAMERAS}"',"type":"'"${CAMERA_TYPE}"'"'

        # complete
        CAMERAS="${CAMERAS}"'}'
        continue
	;;
  esac

  ##
  ## handle more than one motion process (10 is max camera/process); set to 3
  ##
  CAMERA_MAX=3

  if (( CNUM / ${CAMERA_MAX} )); then
    bashio::log.debug "Camera number divisible by ${CAMERA_MAX}"
    if (( CNUM % ${CAMERA_MAX} == 0 )); then
      bashio::log.debug "Camera number modulus of ${CAMERA_MAX}; creating new configuration file; current: ${MOTION_CONF}"

      # new configuration
      CONF="${MOTION_CONF%%.*}.${MOTION_COUNT}.${MOTION_CONF##*.}"

      # start camera numbering over at one
      CNUM=1

      # copy prior configuration
      cp "${MOTION_CONF}" "${CONF}"
      MOTION_CONF=${CONF}
      bashio::log.debug "Created configuration; count: ${MOTION_COUNT}; file: ${MOTION_CONF}"

      # reset camera(s)
      sed -i 's|^camera|; camera|' "${MOTION_CONF}"

      # set stream port
      VALUE=$(jq -r ".stream_port" "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; fi
      VALUE=$((VALUE + MOTION_COUNT))
      sed -i "s/^stream_port .*/stream_port ${VALUE}/" "${MOTION_CONF}"
      bashio::log.debug "Configuration ${MOTION_COUNT}: ${MOTION_CONF}; set stream port: ${VALUE}"

      # set webcontrol_port
      VALUE=$(jq -r ".webcontrol_port" "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
      VALUE=$((VALUE + MOTION_COUNT))
      sed -i "s/^webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
      bashio::log.debug "Configuration ${MOTION_COUNT}: ${MOTION_CONF}; set control port: ${VALUE}"

      MOTION_COUNT=$((MOTION_COUNT + 1))

    else
      CNUM=$((CNUM+1))
    fi
  else
    if [ ${MOTION_COUNT} -eq 0 ]; then MOTION_COUNT=1; fi
    CNUM=$((CNUM+1))
  fi

  # create camera configuration file
  if [ ${MOTION_CONF%/*} != ${MOTION_CONF} ]; then
    CAMERA_CONF="${MOTION_CONF%/*}/${CNAME}.conf"
    bashio::log.debug "Camera configuration file; ${CAMERA_CONF}; ${MOTION_CONF%/*} != ${MOTION_CONF}"
  else
    CAMERA_CONF="${CNAME}.conf"
    bashio::log.debug "Camera configuration file; ${CAMERA_CONF}; ${MOTION_CONF%/*} = ${MOTION_CONF}"
  fi

  # add to JSON
  CAMERAS="${CAMERAS}"',"server":'"${MOTION_COUNT}"
  CAMERAS="${CAMERAS}"',"cnum":'"${CNUM}"
  CAMERAS="${CAMERAS}"',"conf":"'"${CAMERA_CONF}"'"'

  VALUE=$(jq -r '.cameras['${i}'].mjpeg_url' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then
    # calculate mjpeg_url for camera
    VALUE="http://${ipaddr}:$((MOTION_STREAM_PORT+MOTION_COUNT-1))/${CNUM}"
  fi
  bashio::log.debug "Set mjpeg_url to ${VALUE}"
  CAMERAS="${CAMERAS}"',"mjpeg_url":"'${VALUE}'"'

  # addon_api
  CAMERAS="${CAMERAS}"',"addon_api":"'${ADDON_API}'"'

  ##
  ## make camera configuration file
  ##

  # basics
  echo "camera_id ${CNUM}" > "${CAMERA_CONF}"
  echo "camera_name ${CNAME}" >> "${CAMERA_CONF}"
  echo "target_dir ${TARGET_DIR}" >> "${CAMERA_CONF}"
  echo "width ${WIDTH}" >> "${CAMERA_CONF}"
  echo "height ${HEIGHT}" >> "${CAMERA_CONF}"
  echo "movie_max_time ${MOVIE_MAX_TIME}" >> "${CAMERA_CONF}"
  echo "framerate ${FRAMERATE}" >> "${CAMERA_CONF}"
  echo "stream_motion ${STREAM_MOTION}" >> "${CAMERA_CONF}"
  echo "stream_maxrate ${STREAM_MAXRATE}" >> "${CAMERA_CONF}"
  echo "event_gap ${EVENT_GAP}" >> "${CAMERA_CONF}"

  # pre_capture
  VALUE=$(jq -r '.cameras['${i}'].pre_capture' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.pre_capture') && VALUE=${VALUE:-0}; fi
  bashio::log.debug "Set pre_capture to ${VALUE}"
  CAMERAS="${CAMERAS}"',"pre_capture":'"${VALUE}"
  echo "pre_capture ${VALUE}" >> "${CAMERA_CONF}"

  # post_capture
  VALUE=$(jq -r '.cameras['${i}'].post_capture' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.post_capture') && VALUE=${VALUE:-0}; fi
  bashio::log.debug "Set post_capture to ${VALUE}"
  CAMERAS="${CAMERAS}"',"post_capture":'"${VALUE}"
  echo "post_capture ${VALUE}" >> "${CAMERA_CONF}"

  # rotate
  VALUE=$(jq -r '.cameras['${i}'].rotate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.rotate') && VALUE=${VALUE:-0}; fi
  bashio::log.debug "Set rotate to ${VALUE}"
  CAMERAS="${CAMERAS}"',"rotate":'"${VALUE}"
  echo "rotate ${VALUE}" >> "${CAMERA_CONF}"

  # picture_quality
  VALUE=$(jq -r '.cameras['${i}'].picture_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.picture_quality') && VALUE=${VALUE:-50}; fi
  bashio::log.debug "Set picture_quality to ${VALUE}"
  CAMERAS="${CAMERAS}"',"picture_quality":'"${VALUE}"
  echo "picture_quality ${VALUE}" >> "${CAMERA_CONF}"

  # stream_quality
  VALUE=$(jq -r '.cameras['${i}'].stream_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_quality') && VALUE=${VALUE:-50}; fi
  bashio::log.debug "Set stream_quality to ${VALUE}"
  CAMERAS="${CAMERAS}"',"stream_quality":'"${VALUE}"
  echo "stream_quality ${VALUE}" >> "${CAMERA_CONF}"

  # lightswitch_percent
  VALUE=$(jq -r '.cameras['${i}'].lightswitch_percent' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.lightswitch_percent') && VALUE=${VALUE:-0}; fi
  bashio::log.debug "Set lightswitch_percent to ${VALUE}"
  CAMERAS="${CAMERAS}"',"lightswitch_percent":'"${VALUE}"
  echo "lightswitch_percent ${VALUE}" >> "${CAMERA_CONF}"

  # lightswitch_frames
  VALUE=$(jq -r '.cameras['${i}'].lightswitch_frames' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.lightswitch_frames') && VALUE=${VALUE:-5}; fi
  bashio::log.debug "Set lightswitch_frames to ${VALUE}"
  CAMERAS="${CAMERAS}"',"lightswitch_frames":'"${VALUE}"
  echo "lightswitch_frames ${VALUE}" >> "${CAMERA_CONF}"


  ## THRESHOLD

  VALUE=$(jq -r '.cameras['${i}'].threshold' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ] || [ ${VALUE:-0} -le 0 ]; then
    PCT=$(jq -r '.cameras['${i}'].threshold_percent' "${CONFIG_PATH}")
    if [ "${PCT:-null}" = 'null' ] || [ ${PCT:-0} -le 0 ]; then PCT=$(echo "${MOTION}" | jq -r '.threshold_percent'); fi
    if [ "${PCT:-null}" != 'null' ] && [ ${PCT:-0} -gt 0 ]; then
      VALUE=$(echo "${PCT} * ( ${WIDTH} * ${HEIGHT} ) / 100.0" | bc -l) && VALUE=${VALUE%%.*}
    fi
  fi
  if [ "${VALUE:-null}" = 'null' ] || [ ${VALUE:-0} -le 0 ]; then VALUE=$(echo "${MOTION}" | jq -r '.threshold'); fi
  if [ "${PCT:-null}" = 'null' ] || [ ${PCT:-0} -le 0 ]; then PCT=$(echo "${VALUE} / ( ${WIDTH} * ${HEIGHT} ) * 100.0" | bc -l) && PCT=${PCT%%.*}; PCT=${PCT:-null}; fi

  bashio::log.debug "Camera ${CNAME:-}: set threshold_percent to ${PCT}"
  CAMERAS="${CAMERAS}"',"threshold_percent":'"${PCT}"
  bashio::log.debug "Camera ${CNAME:-}: set threshold to ${VALUE}"
  CAMERAS="${CAMERAS}"',"threshold":'"${VALUE}"
  echo "threshold ${VALUE}" >> "${CAMERA_CONF}"

  # set threshold_maximum
  VALUE=$(jq -r '.cameras['${i}'].threshold_maximum' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" == "null" ]; then VALUE=$(echo "${MOTION}" | jq -r '.threshold_maximum') && VALUE=${VALUE:-0}; fi
  CAMERAS="${CAMERAS}"',"threshold_maximum":'"${VALUE:-0}"
  echo "threshold_maximum ${VALUE:-0}" >> "${CAMERA_CONF}"

  # set threshold_tune
  VALUE=$(jq -r '.cameras['${i}'].threshold_tune' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then VALUE=$(echo "${MOTION}" | jq -r '.threshold_tune') && VALUE=${VALUE:-off}; fi
  CAMERAS="${CAMERAS}"',"threshold_tune":"'"${VALUE}"'"'
  echo "threshold_tune ${VALUE}" >> "${CAMERA_CONF}"

  if [ "${CAMERA_TYPE}" == 'netcam' ]; then
    # network camera
    VALUE=$(jq -r '.cameras['${i}'].netcam_url' "${CONFIG_PATH}")
    if [ ! -z "${VALUE:-}" ] && [ "${VALUE:-null}" != 'null' ]; then
      # network camera
      CAMERAS="${CAMERAS}"',"netcam_url":"'"${VALUE}"'"'
      echo "netcam_url ${VALUE}" >> "${CAMERA_CONF}"
      bashio::log.debug "Set netcam_url to ${VALUE}"
      netcam_url=$(echo "${VALUE}" | sed 's/mjpeg:/http:/')

      # userpass
      VALUE=$(jq -r '.cameras['${i}'].netcam_userpass' "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_userpass'); fi
      echo "netcam_userpass ${VALUE}" >> "${CAMERA_CONF}"
      CAMERAS="${CAMERAS}"',"netcam_userpass":"'"${VALUE}"'"'
      bashio::log.debug "Set netcam_userpass to ${VALUE}"
      netcam_userpass=${VALUE}

      # test netcam_url
      alive=$(curl --anyauth -fsqL -w '%{http_code}' --connect-timeout 2 --retry-connrefused --retry 10 --retry-max-time 2 --max-time 15 -u "${netcam_userpass:-null}" "${netcam_url:-null}" -o /dev/null 2> /dev/null || true)
      bashio::log.info "TEST: camera: ${CNAME}; type: ${CAMERA_TYPE}; response: ${alive:-null}; URL: ${netcam_url:-null}"
      CAMERAS="${CAMERAS}"',"response":"'"${alive}"'"'

      if [ "${alive:-}" != '200' ]; then
        bashio::log.debug "BAD: ${alive:-null}; camera: ${CNAME}; URL: ${netcam_url:-null}; userpass: ${netcam_userpass:-null}"
      else
        bashio::log.debug "GOOD: ${alive:-null}; camera: ${CNAME}; URL: ${netcam_url:-null}; userpass: ${netcam_userpass:-null}"
      fi

      # keepalive
      VALUE=$(jq -r '.cameras['${i}'].keepalive' "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_keepalive'); fi
      echo "netcam_keepalive ${VALUE}" >> "${CAMERA_CONF}"
      CAMERAS="${CAMERAS}"',"keepalive":"'"${VALUE}"'"'
      bashio::log.debug "Set netcam_keepalive to ${VALUE}"
    else
      bashio::log.error "No netcam_url specified: ${VALUE}; skipping"
      # close CAMERAS structure
      CAMERAS="${CAMERAS}"'}'
      continue;
    fi
  elif [ "${CAMERA_TYPE}" == 'local' ]; then
    # local camera
    VALUE=$(jq -r '.cameras['${i}'].device' "${CONFIG_PATH}")
    if [ "${VALUE:-null}" != 'null' ] ; then
      if [[ "${VALUE}" != /dev/video* ]]; then
        bashio::log.error "Camera: ${i}; name: ${CNAME}; invalid videodevice ${VALUE}; exiting"
        exit 1
      fi
    else
      VALUE="/dev/video0"
    fi
    echo "videodevice ${VALUE}" >> "${CAMERA_CONF}"
    device=${VALUE}
    bashio::log.debug "Set videodevice to ${VALUE}"

    # palette
    VALUE=$(jq -r '.cameras['${i}'].palette' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.palette'); fi
    CAMERAS="${CAMERAS}"',"palette":'"${VALUE}"
    echo "v4l2_palette ${VALUE}" >> "${CAMERA_CONF}"
    bashio::log.debug "Set palette to ${VALUE}"
    bashio::log.info "TEST: camera: ${CNAME}; device: ${device:-null}; palette: ${VALUE:-null}"
  else
    bashio::log.error "Invalid camera type: ${CAMERA_TYPE}"
  fi

  # close CAMERAS structure
  CAMERAS="${CAMERAS}"'}'

  # add new camera configuration
  echo "camera ${CAMERA_CONF}" >> "${MOTION_CONF}"
done
# finish CAMERAS
if [ -n "${CAMERAS:-}" ]; then
  CAMERAS="${CAMERAS}"']'
else
  CAMERAS='null'
fi

bashio::log.debug "CAMERAS: $(echo "${CAMERAS}" | jq -c '.')"
bashio::log.info "Completed processing cameras:" $(echo "${CAMERAS:-null}" | jq '.|length')

###
## append camera, finish JSON configuration, and validate
###

JSON="${JSON}"',"cameras":'"${CAMERAS}"'}'
echo "${JSON}" | jq -c '.' > "$(motion.config.file)"
if [ ! -s "$(motion.config.file)" ]; then
  bashio::log.error "INVALID CONFIGURATION; metadata: ${JSON}"
  exit 1
fi
bashio::log.debug "CONFIGURATION; file: $(motion.config.file); metadata: $(jq -c '.' $(motion.config.file))"

###
## configure inotify() for any 'ftpd' cameras
###

bashio::log.info "Settting up notifywait for FTPD cameras"
ftp_notifywait.sh "$(motion.config.file)"

###
# start Apache
###

# make the options available to the apache client
chmod go+rx /data /data/options.json
start_apache_background ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}
bashio::log.notice "Started Apache on ${MOTION_APACHE_HOST}:${MOTION_APACHE_PORT}"

iperf3 -s -D
bashio::log.notice "Started iperf3"

echo 'Modifying NetData to enable access from any host' \
  && sed -i 's/127.0.0.1/\*/' /etc/netdata/netdata.conf \
  && sed -i 's/localhost/\*/' /etc/netdata/netdata.conf \
  && echo 'SEND_EMAIL="NO"' > /etc/netdata/health_alarm_notify.conf \
  || echo 'Failed to modify netdata.conf' &> /dev/stderr

echo 'Restarting netdata' \
  && netdata -d &> /dev/null \
  || echo 'Failed to restart netdata' &> /dev/stderr

###
## start all motion daemons
###

PID_FILES=()
CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"
# process all motion configurations
for (( i = 1; i <= MOTION_COUNT;  i++)); do
  # test for configuration file
  if [ ! -s "${CONF}" ]; then
     bashio::log.error "missing configuration for daemon ${i} with ${CONF}"
     exit 1
  fi
  bashio::log.debug "Starting motion configuration ${i}: ${CONF}"
  PID_FILE="${MOTION_CONF%%.*}.${i}.pid"
  motion -b -c "${CONF}" -p ${PID_FILE}
  PID_FILES=(${PID_FILES[@]} ${PID_FILE})

  # get next configuration
  CONF="${MOTION_CONF%%.*}.${i}.${MOTION_CONF##*.}"
done

## started
bashio::log.notice "Started ${#PID_FILES[@]} motion daemons"

## reload Home Assistant iff requested and necessary
motion::reload

## forever
while true; do

    ## publish configuration
    ( motion.mqtt.pub -r -q 2 -t "$(motion.config.group)/$(motion.config.device)/start" -f "$(motion.config.file)" \
      && bashio::log.info "Published configuration to MQTT; topic: $(motion.config.group)/$(motion.config.device)/start" ) \
      || bashio::log.error "Failed to publish configuration to MQTT; config: $(motion.config.mqtt)"

    ## check on daemons
    if [ ${#PID_FILES[@]} -gt 0 ]; then i=0; for PID_FILE in ${PID_FILES[@]}; do
      if [ ! -z "${PID_FILE:-}" ] && [ -s "${PID_FILE}" ]; then
        pid=$(cat ${PID_FILE})
        if [ "${pid:-null}" != 'null' ]; then
          found=$(ps alxwww | grep 'motion -b' | awk '{ print $1 }' | egrep ${pid} || true)
          if [ -z "${found:-}" ]; then
            bashio::log.warning "Daemon with PID: ${pid} is not found; restarting"
            if [ ${i} -gt 0 ]; then
              CONF="${MOTION_CONF%%.*}.${i}.${MOTION_CONF##*.}"
            else
              CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"
            fi
            motion -b -c "${CONF}" -p ${PID_FILE}
          else
            bashio::log.debug "motion daemon running with PID: ${pid}"
          fi
        else
          bashio::log.error "PID file contents invalid: ${PID_FILE}"
        fi
      else
        bashio::log.error "No motion daemon PID file: ${PID_FILE}"
      fi
      i=$((i+1))
    done; fi

    ## sleep
    bashio::log.info "Sleeping; ${MOTION_WATCHDOG_INTERVAL:-1800} seconds ..."
    sleep ${MOTION_WATCHDOG_INTERVAL:-1800}

done
