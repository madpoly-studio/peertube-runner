#!/bin/sh
#
# The container user (see USER in the Dockerfile) is an un-privileged user that
# does not exist and is not created during the build phase (see Dockerfile).
# Hence, we use this entrypoint to wrap commands that will be run in the
# container to create an entry for this user in the /etc/passwd file.
#
# The following environment variables may be passed to the container to
# customize running user account:
#
#   * USER_NAME: container user name (default: default)
#   * HOME     : container user home directory (default: none)
#
# To pass environment variables, you can either use the -e option of the docker run command:
#
#     docker run --rm -e USER_NAME=foo -e HOME='/home/foo' peertube-runner:latest peertube-runner server
#
#

# echo "🐳(entrypoint) creating user running in the container..."
# if ! whoami >/dev/null 2>&1; then
#   if [ -w /etc/passwd ]; then
#     echo "${USER_NAME:-default}:x:$(id -u):$(id -g):${USER_NAME:-default} user:${HOME}:/sbin/nologin" >>/etc/passwd
#   fi
# fi

# Generat TOML file to run peertube-runner

reload_service() {
  kill -9 1 &
  /entrypoint.sh
}

update_config() {
  if [ -n "$PEERTUBE_RUNNER_JOBS_CONCURRENCY" ]; then
    sed -r -i "s|^concurrency \= [0-9]+|concurrency = $PEERTUBE_RUNNER_JOBS_CONCURRENCY|" $CONFIG_FILE
  fi

  if [ -n "$PEERTUBE_RUNNER_FFMPEF_THREADS" ]; then
    sed -r -i "s|^threads \= [0-9]+|threads = $PEERTUBE_RUNNER_FFMPEF_THREADS|" $CONFIG_FILE
  fi

  if [ -n "$PEERTUBE_RUNNER_FFMPEG_NICE" ]; then
    sed -r -i "s|^nice \= [0-9]+|nice = $PEERTUBE_RUNNER_FFMPEG_NICE|" $CONFIG_FILE
  fi
}

register() {
  echo "Register runner: $*"
  if [ "$1" = "peertube-runner" ] && [ "$2" = "server" ]; then
    sleep 3

    peertube-runner register \
      --id default \
      --url $PEERTUBE_RUNNER_INSTANCE_URL \
      --registration-token $PEERTUBE_RUNNER_REGISTER_TOKEN \
      --runner-name "${PEERTUBE_RUNNER_PREFIX}${HOSTNAME}"

    peertube-runner --id default list-registered

    reload_service
  fi
}

# Run command used as argument
echo "🐳(entrypoint) running your command: ${*}"

CONFIG_DIRECTORY=~/.config/peertube-runner-nodejs/default
CONFIG_FILE="$CONFIG_DIRECTORY"/config.toml

if [ ! -f "$CONFIG_FILE" ] || ! (cat $CONFIG_FILE | grep "runnerName = \"${PEERTUBE_RUNNER_PREFIX}${HOSTNAME}\""); then
  register "$@" &
else
  update_config
  cat $CONFIG_FILE
fi

exec "$@"

