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
export JAVA8_HOME='/Library/Java/JavaVirtualMachines/temurin-8.jdk/Contents/Home'
export JAVA11_HOME='/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home'
export JAVA17_HOME='/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home'
export JAVA19_HOME='/Library/Java/JavaVirtualMachines/temurin-19.jdk/Contents/Home'
export JAVA21_HOME='/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home'

export JAVA_HOME="${JAVA17_HOME}"

#|> Scala
export SCALA2_HOME='/usr/local/opt/scala@2.13'
export SCALA3_HOME='/usr/local/opt/scala'

export SCALA_HOME="${SCALA2_HOME}"

#|> Maven
# https://github.com/adoptium/jdk17u/blob/master/src/java.base/share/classes/sun/launcher/resources/launcher.properties#L153-L154
export MAVEN_OPTS='-Xms512m -Xmx2G'

#|> Android
# Reference: https://developer.android.com/tools/variables
export ANDROID_HOME="${HOME}/Library/Android/sdk"
export ANDROID_SDK_ROOT="${ANDROID_HOME}"

export ANDROID_BUILD_TOOLS="${ANDROID_HOME}/build-tools/34.0.0"
export ANDROID_EMULATOR_TOOLS="${ANDROID_HOME}/emulator"
export ANDROID_PLATFORM_TOOLS="${ANDROID_HOME}/platform-tools"
export ANDROID_TOOLS="${ANDROID_HOME}/tools"

[ -d "${ANDROID_BUILD_TOOLS}" ] && export PATH="${PATH}:${ANDROID_BUILD_TOOLS}"
[ -d "${ANDROID_EMULATOR_TOOLS}" ] && export PATH="${PATH}:${ANDROID_EMULATOR_TOOLS}"
[ -d "${ANDROID_PLATFORM_TOOLS}" ] && export PATH="${PATH}:${ANDROID_PLATFORM_TOOLS}"
[ -d "${ANDROID_TOOLS}" ] && export PATH="${PATH}:${ANDROID_TOOLS}"

#|> Gradle
export GRADLE_USER_HOME="${HOME}/.gradle"

#|> Starship
export STARSHIP_CONFIG="${HOME}/.config/starship/starship.toml"
