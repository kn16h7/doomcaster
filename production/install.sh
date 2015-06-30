#!/bin/bash

echo "Installing jurandir.rb..."

LISTS_PATH=$HOME/.jurandir.rb/lists


if ! mkdir -p $LISTS_PATH; then
	echo "FATAL: Failed to create lists directory"
	exit 1
fi

if ! cp lists/* $LISTS_PATH; then
	echo "FATAL: Failed to move lists to the lists path"
	exit 1
fi

echo "list set up OK"
echo "Installing gem..."

gem install jurandir.rb*.gem

echo "jurandir.rb installed with success"
