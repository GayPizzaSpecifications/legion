#!/usr/bin/env bash
set -e

eval ${@}

${CC} ${CFLAGS} ${PROJECT}/hello.c -o hello
