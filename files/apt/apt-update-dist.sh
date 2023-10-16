#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
APT_OPTS="-y -o DPkg::Options::=--force-confdef -o DPkg::Options::=--force-confold"

apt-get $APT_OPTS dist-upgrade

