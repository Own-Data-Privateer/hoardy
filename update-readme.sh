#!/bin/sh -e

echo '$table-of-contents$' > toc.template
for i in 0 1; do
{
    echo "# Table of Contents"
    echo "<details><summary>(Click me to see it.)</summary>"
    pandoc --wrap=none --toc --template=toc.template -M title=toc -f markdown -t html README.md \
        | sed '/Table of Contents/ d; s%<span id="[^"]*"/>%%'
    echo "</details>"
    echo

    sed -n "/# What is/,/# Usage/ p" README.md
    echo

    python3 -m hoardy.__main__ --help --markdown | sed '
s/^\(#\+\) /#\1 /
s/^\(#\+\) \(hoardy[^[({]*\) [[({].*/\1 \2/
'
    echo

    ./test-hoardy.sh --help | sed '
s/^# usage: \(.*\)$/# Development: `\1`/
'
} > README.new
mv README.new README.md
done
pandoc -f markdown -t html README.md > README.html
