#!/bin/bash
groups "$1" | grep sudo
exit $?