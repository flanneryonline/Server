#!/bin/bash

#check for services to restart
cat /var/run/reboot-required.pkgs
#or
lsof | grep lib | grep DEL