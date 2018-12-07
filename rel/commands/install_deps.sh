#!/bin/env sh

LINUX_DEPS="build-essential automake autoconf autogen libncurses-dev libgmp-dev libtinfo-dev libncursesw5-dev libncurses5-dev libtool gcc curl postgresql redis-server openssl"
DARWIN_DEPS="automake autoconf autogen libgmp-dev postgresql redis"

fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\\n$fmt\\n" "$@"
}

install_linux_deps() {
  local flavor=`grep "^ID=" /etc/os-release | cut -d"=" -f 2`
  case $flavor in
    debian|ubuntu)
      sudo apt-get update && sudo apt-get update && sudo apt-get install -y $LINUX_DEPS libgmp-dev erlang-dev
      ;;
    fedora|centos)
      sudo yum install $LINUX_DEPS gmp-devel
      ;;
    *)
      fancy_echo "Unrecognized distribution $flavor"
      exit 1
      ;;
  esac
}

install_darwin_deps(){
    fancy_echo "Installing dependencies via brew"
    brew install $DARWIN_DEPS
}

install_deps() {
  local sys=`uname -s`
  echo $sys
  case $sys in
    Linux*)
      install_linux_deps
      ;;
    Darwin*)
      install_darwin_deps
      ;;
    *)
      fancy_echo "Unknown system"
      exit 1
      ;;
  esac
}
set -e
install_deps
