#!/bin/sh

release_ctl eval --mfa "Blacksmith.ReleaseTasks.migrate/1" --argv -- "$@"
