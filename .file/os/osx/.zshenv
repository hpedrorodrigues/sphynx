#!/usr/bin/env bash

# Add some basic paths to PATH variable

readonly BASIC_PATHS=(
  '/bin'
  '/usr/bin'
  '/usr/sbin'
  '/usr/local/bin'
  '/usr/local/sbin'
  "${HOME}/.local/bin"
)

for basic_path in ${BASIC_PATHS[*]}; do
  if [ -d "${basic_path}" ] && echo "${PATH}" | grep "${basic_path}" -v -q; then
    export PATH="${PATH}:${basic_path}"
  fi
done

#|> Java
export JAVA8_HOME='/Library/Java/JavaVirtualMachines/adoptopenjdk-8-openj9.jdk/Contents/Home'
export JAVA11_HOME='/Library/Java/JavaVirtualMachines/adoptopenjdk-11-openj9.jdk/Contents/Home'
export JAVA13_HOME='/Library/Java/JavaVirtualMachines/adoptopenjdk-13-openj9.jdk/Contents/Home'
export JAVA_HOME="${JAVA8_HOME}"

[ -d "${JAVA_HOME}" ] && export PATH="${PATH}:${JAVA_HOME}"

#|> Maven
export MAVEN_OPTS='-Xms512m -Xmx1G'

#|> dx
export DX_CONFIRMATION_REQUIRED=false

#|> Android
# References:
# - https://developer.android.com/studio/command-line/variables
export ANDROID_PLATFORM_VERSION='30.0.1'

export ANDROID_HOME="${HOME}/Library/Android/sdk"
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

#|> Gradle
export GRADLE_USER_HOME="${HOME}/.gradle"

#|> Bat
export BAT_THEME='TwoDark'

#|> Starship
export STARSHIP_CONFIG="${HOME}/.config/starship/starship.toml"
