#!/bin/sh -e

black $1 *.py hoardy
mypy
#pytest -k 'not slow'
pylint *.py hoardy
./update-readme.sh
if [[ "$1" == "--check" ]]; then
    ./test-hoardy.sh default
fi
