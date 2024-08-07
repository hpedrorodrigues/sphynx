#!/usr/bin/env bash

# Add some basic paths to PATH variable

export BASIC_PATHS=(
  '/bin'
  '/usr/bin'
  '/usr/sbin'
  '/usr/local/bin'
  '/usr/local/sbin'
  "${HOME}/.local/bin"
)

# shellcheck disable=SC2048  # Use "$@" (with quotes) to prevent whitespace problems
for basic_path in ${BASIC_PATHS[*]}; do
  if [ -d "${basic_path}" ] && [[ "${PATH}" != *"${basic_path}"* ]]; then
    export PATH="${PATH}:${basic_path}"
  fi
done

unset BASIC_PATHS

#|> Java
export JAVA8_HOME='/usr/lib/jvm/java-8-openjdk-amd64'
export JAVA11_HOME='/usr/lib/jvm/java-11-openjdk-amd64'
export JAVA13_HOME='/usr/lib/jvm/java-13-openjdk-amd64'
export JAVA_HOME="${JAVA11_HOME}"

[ -d "${JAVA_HOME}" ] && export PATH="${PATH}:${JAVA_HOME}"

#|> Maven
# https://github.com/adoptium/jdk17u/blob/master/src/java.base/share/classes/sun/launcher/resources/launcher.properties#L153-L154
export MAVEN_OPTS='-Xms512m -Xmx2G'

#|> Gradle
export GRADLE_USER_HOME="${HOME}/.gradle"

#|> x11
# https://www.x.org/wiki
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-"${HOME}/.config"}"

#|> Android
# References:
# - https://developer.android.com/studio/command-line/variables
export ANDROID_PLATFORM_VERSION='31.0.0'

export ANDROID_HOME="${HOME}/Android/Sdk"
export ANDROID_SDK_ROOT="${ANDROID_HOME}"
export ANDROID_TOOLS="${ANDROID_HOME}/tools"
export ANDROID_BUILD_TOOLS="${ANDROID_HOME}/build-tools/${ANDROID_PLATFORM_VERSION}"
export ANDROID_PLATFORM_TOOLS="${ANDROID_HOME}/platform-tools"
export ANDROID_EMULATOR_TOOLS="${ANDROID_HOME}/emulator"

[ -d "${ANDROID_HOME}" ] && export PATH="${PATH}:${ANDROID_HOME}"
[ -d "${ANDROID_TOOLS}" ] && export PATH="${PATH}:${ANDROID_TOOLS}:${ANDROID_TOOLS}/bin"
[ -d "${ANDROID_BUILD_TOOLS}" ] && export PATH="${PATH}:${ANDROID_BUILD_TOOLS}"
[ -d "${ANDROID_PLATFORM_TOOLS}" ] && export PATH="${PATH}:${ANDROID_PLATFORM_TOOLS}"
[ -d "${ANDROID_EMULATOR_TOOLS}" ] && export PATH="${PATH}:${ANDROID_EMULATOR_TOOLS}"

#|> Starship
export STARSHIP_CONFIG="${HOME}/.config/starship/starship.toml"

#|> Linuxbrew
export LINUXBREW_HOME="${HOME}/.linuxbrew"
export LINUXBREW_BIN="${LINUXBREW_HOME}/bin/brew"

export LINUXBREW_USER_HOME='/home/linuxbrew/.linuxbrew'
export LINUXBREW_USER_BIN="${LINUXBREW_USER_HOME}/bin/brew"

[ -d "${LINUXBREW_HOME}" ] && [ -f "${LINUXBREW_BIN}" ] \
  && eval "$("${LINUXBREW_BIN}" shellenv)"

[ -d "${LINUXBREW_USER_HOME}" ] && [ -f "${LINUXBREW_USER_BIN}" ] \
  && eval "$("${LINUXBREW_USER_BIN}" shellenv)"

hash brew 2>/dev/null \
  && eval "$("$(brew --prefix)/bin/brew" shellenv)"
