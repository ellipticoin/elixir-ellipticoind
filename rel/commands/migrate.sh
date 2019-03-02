#!/bin/sh

release_ctl eval --mfa "Node.ReleaseTasks.migrate/1" --argv -- "$@"
