#!/bin/bash
exec 2>&1
echo "*** Starting gui ***"

. /etc/profile.d/qt4.sh

# when headless:
# - vnclocal: force-enable it, so a user can never lock himself out. And, if there is no
#   pwd-file yet, create an empty one
# - vncinternet: default enable into localsettings, but don't force enable: user can switch
#   it off.
# - run gui with -display "VNC::etc etc "
#
# when headfull:
# - add vnclocal & vncinternet with default off into localsettings
# - enable / disable each based on their config in localsettings
# - run gui with -display "Multi:: VNC::etc etc"

function add_int_setting()
{
  category="$1"
  setting="$2"
  default="$3"
  min="$4"
  max="$5"

  dbus-send --system --print-reply --dest=com.victronenergy.settings /Settings com.victronenergy.Settings.AddSetting string:"$category" string:"$setting" "variant:int32:$default" string:"i" "variant:int32:$min" "variant:int32:$max" &> /dev/null
}

# The /etc/venus/headless file is present on headless devices, such as the beaglebone.
# Its created by the machine-runtime-conf recipe.
if [ -f /etc/venus/headless -o ! -e /dev/fb0 ]; then
	headless=1
	size=480x272
else
	headless=0
	size=$(fbset -fb /dev/fb0 | awk '/geometry/ { print $2 "x" $3 }')
fi
echo "*** headless device=$headless"

if [ -n "$QWS_MOUSE_PROTO" ]; then
    mouse=-mouse
else
    mouse=-nomouse
fi

echo "*** Waiting for localsettings..."
until add_int_setting System VncLocal "$headless" 0 1; do sleep 1; done
echo "*** Localsettings is up, continuing..."
add_int_setting System VncInternet "$headless" 0 1

if [ "$headless" -eq 1 ]; then
	# Force enable VncLocal
	dbus-send --system --print-reply --dest=com.victronenergy.settings /Settings/System/VncLocal com.victronenergy.BusItem.SetValue variant:int32:1

	# If file doesn't exist already, generate empty password file for
	# Remote Console
	touch /data/conf/vncpassword.txt

	vnclocal=1
	multistring=""
else
	multistring="Multi: LinuxFb: "
	vnclocal="$(dbus-send --system --print-reply --dest=com.victronenergy.settings /Settings/System/VncLocal com.victronenergy.BusItem.GetValue | grep variant | awk '{print $3;}')"
fi

vncinternet="$(dbus-send --system --print-reply --dest=com.victronenergy.settings /Settings/System/VncInternet com.victronenergy.BusItem.GetValue | grep variant | awk '{print $3;}')"

scriptdir=$(dirname "$BASH_SOURCE")

# reset brightness range after GUI starts
nohup sleep 1; dbus -y com.victronenergy.settings /Settings AddSettings '%[{"path": "/Gui/Brightness", "default":255, "min":0, "max":255}]' > /dev/null &

if [ "$vnclocal" = "1" ] || [ "$vncinternet" = "1" ]; then
	echo "*** Starting gui, with VNC enabled (VncLocal=$vnclocal VncInternet=$vncinternet)"
	exec ${scriptdir}/gui $mouse -display "${multistring}VNC:size=$size:depth=32:passwordFile=/data/conf/vncpassword.txt:0"
else
	echo "*** Starting gui, with VNC disabled (VncLocal=$vnclocal VncInternet=$vncinternet)"
	exec ${scriptdir}/gui $mouse
fi
