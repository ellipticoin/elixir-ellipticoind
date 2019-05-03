#!/bin/sh

release_ctl eval --mfa "Ellipticoind.ReleaseTasks.migrate/1" --argv -- "$@"
