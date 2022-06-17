# `QUICKSTART.md`

# Age@Home installation

**Install [Home-Assistant](http://home-assistant.io) using these [instructions](HOMEASSISTANT.md)** prior to installing Age@Home.

## Installing the _add-on_

The Age@Home add-on is installed through the [**add-on dashboard**](http://homeassistant.local:8123/hassio/dashboard) which initiallly is empty, but provides a link to the [**add-on store**](http://homeassistant.local:8123/hassio/store) similar to the image below.

<img width='70%' src='ha-addon-store.png'>

The add-on container for the Age@Home add-on is securely distributed from the [Docker hub](https://hub.docker.com/repository/docker/dcmartin/addon-ageathome) from the open-source at [github.com/ageathome](http://github.com/ageathome)


### 1. Add the repository
The Age@Home add-on is cataloged in a [repository](http://github.com/ageathome/addons) that provides requisite information for automated deployment through Home-Assistant; see more about [_add-ons_](http://home-assistant.io/addons).

<img width="50%" src='ha-addon-repositories.png'>

### Commands

```
git clone http://github.com/dcmartin/motion-ai /share/motion-ai
git clone http://github.com/ageathome/core /share/ageathome
cd /share/ageathome
ln -s /share/motion-ai .
apk add make gettext sudo
```

```
cd /share/ageathome/homeassistant
PACKAGES= make
tar chf - . | ( cd /config ; tar xf - )
```

```
pushd /share/motion-ai; git pull; popd
pushd /share/ageathome; git pull; popd
```

