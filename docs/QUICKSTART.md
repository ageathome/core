# `QUICKSTART.md`

**Install [Home-Assistant](http://home-assistant.io)** prior to installing Age@Home. Follow these [instructions](HOMEASSISTANT.md) for RaspberryPi

Alternatively use a virtual machine:

- Download [VirtualBox](https://www.virtualbox.org/) and Home Assistant OS [image (v9.2)](https://github.com/home-assistant/operating-system/releases/download/9.2/haos_ova-9.2.vdi.zip).  Create a virtual machine: LINUX/4.x (64-bit) with 3GB RAM; EFI enable; bridged networking; Intel Audio.  Recommended to resize image to at least 64GB+ using VirtualBox's virtual media manager.


# Installing the _add-on_

The Age@Home add-on is installed through the [**add-on dashboard**](http://homeassistant.local:8123/hassio/dashboard) which initiallly is empty, but provides a link to the [**add-on store**](http://homeassistant.local:8123/hassio/store) similar to the image below.

<img width='70%' src='ha-addon-store.png'>

The add-on container for the Age@Home add-on is securely distributed from the [Docker hub](https://hub.docker.com/repository/docker/dcmartin/addon-ageathome) from the open-source at [github.com/ageathome](http://github.com/ageathome)


## 1. Add the repository
The Age@Home add-on is cataloged in a [repository](http://github.com/ageathome/addons) that provides requisite information for automated deployment through Home-Assistant; see more about [_add-ons_](http://home-assistant.io/addons).

Enter the value `http://github.com/ageathome/addons` as indicated below and click `ADD`

<img width="50%" src='ha-addon-repositories.png'>

## 2. Install the add-on

Adding the repository creates a new item in the Add-on Store similar to the image below.

<img width="50%" src='ageathome-repository.png'>

Selecting the item displays `Info` and `Documentation` panels for the add-on similar to the image below.

<img width="75%" src='ageathome-addon.png'>

Optionally review documentation and click on `INSTALL`

## 3. Start Age@Home

Once the add-on has been installed it will display options for _Start on Boot_, _Watchdog_, _Auto update_, and _Show in sidebar_ similar to the image below.

<img width="50%" src='ageathome-installed.png'>

Start the add-on by clicking `START` on the lower-left.  After a few momenets the display should change to indicate success similar to the image below.

<img width="50%" src='ageathome-started.png'>

Once the Age@Home add-on has completed initialization it will reboot the hub.

