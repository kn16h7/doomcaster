#!/bin/bash

echo "Installing DoomCaster..."

LISTS_PATH=$HOME/.doomcaster/

if ! mkdir -p $LISTS_PATH; then
	echo "FATAL: Failed to create DoomCaster home directory"
	exit 1
fi

if ! cp -r wordlists/* $LISTS_PATH; then
	echo "FATAL: Failed to move wordlists to the lists path"
	exit 1
fi

echo "List set up OK"
echo "Installing gem..."

gem install doomcaster*.gem

echo "DoomCaster installed with success"
