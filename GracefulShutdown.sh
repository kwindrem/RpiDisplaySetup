#!/bin/bash

# part of RpiGpioSetup package

# monitors GPIO pin for shutdown signal (pulled low to shutdown)
# export GPIO pin and set to input
# gpioPin must be in /etc/venus/gpio_list

# this script runs as a service

gpioPin=16

echo "Raspberry PI gracefull shutdown script starting"

# echo "$gpioPin" > /sys/class/gpio/export
# echo "in" > /sys/class/gpio/gpio$gpioPin/direction

# wait for pin to go low
while [ true ] ; do
    # if GPIO pin isn't set up, don't do anything
    if [ ! -f /sys/class/gpio/gpio$gpioPin/value ]; then
        echo "No shutdown GPIO pin defined"
        sleep 600
    elif [ "$(cat /sys/class/gpio/gpio$gpioPin/value)" == '1' ] ; then
        echo "Raspberry Pi Shutting Down!"
        shutdown -h now
        sleep 5 100
        exit 0
    fi
sleep 1
done
