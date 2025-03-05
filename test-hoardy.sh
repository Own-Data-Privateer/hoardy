#!/usr/bin/env bash

#set -x

. ./vendor/kisstdlib/devscript/test-cli-lib.sh

usage() {
    cat << EOF
# usage: $0 [--help] [--wine] [--fast] [default] [(NAME|PATH)]*

Sanity check and test \`hoardy\` command-line interface.

## Examples

- Run internal tests:

  \`\`\`
  $0 default
  \`\`\`

- Run fixed-output tests on a given directory:

  \`\`\`
  $0 ~/rarely-changing-path
  \`\`\`

  This will copy the whole contents of that path to \`/tmp\` first.
EOF
}

export PYTHONPATH="$PWD:$PYTHONPATH"

in_wine=
debug_args=()
self() {
    local cmd="$1"
    shift
    if [[ -z "$in_wine" ]]; then
        python3 -m hoardy "$cmd" -d test.db --no-progress "${debug_args[@]}" "$@"
    else
        wine python -m hoardy "$cmd" -d test.db --no-progress "${debug_args[@]}" "$@"
    fi
}

tree1() {
    mkdir one
    mkdir t2wo
    mkdir t3hree
    mkdir t3hree/xfour

    make_regular one/1 "2001-01-01 00:00:01" "text 1"
    make_regular one/a2 "2001-01-01 00:00:02" "text 22"
    make_regular one/b3 "2001-01-01 00:00:03" "text 333"
    make_regular one/c4 "2001-01-01 00:00:04" "text 4444"

    make_regular t2wo/d5 "2000-01-01 00:00:05" "text 1"
    make_regular t2wo/de6z "2000-01-01 00:00:06" "text 22"
    make_regular t2wo/def7 "2000-01-01 00:00:07" "text 333"

    make_regular t3hree/8x "2001-01-01 00:00:08" "text 1"
    make_regular t3hree/g9xz "2001-01-01 00:00:09" "text 22"
    make_regular t3hree/xfour/ghjkl10xyz "2001-01-01 00:00:10" "text 1"

    make_symlink one/l1 "2001-01-01 00:00:01" 1
    make_symlink t2wo/l2 "2000-01-01 00:00:02" "text 1"
    make_symlink t3hree/l3 "2000-01-01 00:00:01" "text 1"
}

tree1mtime() {
    mkdir a
    (
        cd a
        tree1
        find . -type f -exec touch -h -d "2000-01-01 00:00:00" {} \;
        find . -type l -exec touch -h -d "2000-01-01 00:00:00" {} \;
    )
    mkdir b
    (
        cd b
        tree1
        find . -type f -exec touch -h -d "2001-01-01 00:00:00" {} \;
        find . -type l -exec touch -h -d "2001-01-01 00:00:00" {} \;
    )
    for x in c z; do
        mkdir $x
        (
            cd $x
            tree1
            find . -type f -exec touch -h -d "2010-01-01 00:00:00" {} \;
            find . -type l -exec touch -h -d "2010-01-01 00:00:00" {} \;
        )
    done
}

tree1collide() {
    tree1
    mkdir xcollide
    make_regular xcollide/1 "2001-01-01 00:00:01" "nyanyanya218"
}

tree2() {
    tree1
    # for `--order-paths basename`
    mv t3hree/8x t3hree/0
}

tree3() {
    tree1
    chmod 400 one/*
}

tree4() {
    mkdir v1
    (
        cd v1
        tree1
    )
    mkdir v2
    (
        cd v2
        tree2
        find . -type f -exec touch -h -d "2002-01-01 00:00:00" {} \;
        find . -type l -exec touch -h -d "2003-01-01 00:00:00" {} \;
    )
}

corrupt_and_verify() {
    local corruptor="$1"
    shift

    if [[ -n "$corruptor" ]]; then
        eval "$corruptor"
        set_subtree_dir_mtimes test "2010-01-01 00:00:00"
    fi

    cat > expected
    any_stdio2 got "$@"
    sed -i "s%$tmpdir/\([^/]*/\)\?test/%%g" got

    set_subtree_dir_mtimes test "2010-01-01 00:00:00"
    describe-forest --modes --mtimes test > describe-dir.new

    if ! diff describe-dir.old describe-dir.new > /dev/null ; then
        echo "# dir diff" >> got
        diff -U 0 describe-dir.old describe-dir.new | tail -n +3 | sed '/^@@/ d' >> got
    fi
    mv describe-dir.new describe-dir.old

    if ! diff -U 1 expected got ; then
        error "failed $*"
    fi
}

current_target=.
check() {
    local target="$1"
    local maker="$2"
    local corruptor="$3"
    shift 3

    start "$target: $*${corruptor:+ corrupted with $corruptor}"
    current_target="$target"

    mkdir "$tmpdir/$target"
    cd "$tmpdir/$target"
    mkdir test
    (
        cd test
        eval "$maker"
    )

    set_subtree_dir_mtimes test "2010-01-01 00:00:00"

    describe-forest --modes --mtimes test > describe-dir.old
    ok_no_stderr self index --verbose test
    ok_no_stderr self fsck --verbose test

    corrupt_and_verify "$corruptor" "$@"

    end
}

subcheck() {
    start "... $*"

    cd "$tmpdir/$current_target"
    corrupt_and_verify "" "$@"

    end
}

sanity_no_changes() {
    describe-forest --modes --mtimes test > describe-dir.new
    if ! diff -U 0 describe-dir.old describe-dir.new ; then
        error "failed sanity_no_changes"
    fi
    rm describe-dir.new
}

fast=

sanity_noop_deduplicate() {
    if [[ -z "$fast" ]]; then
        subcheck self deduplicate test <<EOF
EOF

        subcheck self deduplicate --order abspath test <<EOF
EOF

        sanity_no_changes
    fi
}

sanity_empty_find_dupes() {
    subcheck self find-dupes test <<EOF
EOF
}

sanity_noop() {
    if [[ -z "$fast" ]]; then
        start "... self deduplicate --dry-run"

        cd "$tmpdir/$current_target"
        self deduplicate --dry-run test &> /dev/null
        self deduplicate --dry-run --delete test &> /dev/null
        sanity_no_changes

        end

        subcheck self fsck test <<EOF
EOF

        subcheck self index --verbose test <<EOF
EOF
    fi

    start "... no changes"
    sanity_no_changes
    end
}


sanity_tree1_find_dupes_boring() {
        subcheck self find-dupes --min-inodes 1 test <<EOF
one/b3
t2wo/def7

one/a2
t2wo/de6z
t3hree/g9xz

t2wo/l2
t3hree/l3

one/1
t2wo/d5
t3hree/8x
t3hree/xfour/ghjkl10xyz

EOF
}

fixed_stdio() {
    local src="$1"
    local got="$2"
    shift 2

    ok_stdio2 "$got.out" "$@"
    sed -i "s%$tmpdir/test/%%g" "$got.out"
    fixed_file "$src" "$got.out"
}

[[ $# < 1 ]] && die "need at least one source"

opts=1
subset=
short=

while (($# > 0)); do
    if [[ -n "$opts" ]]; then
        case "$1" in
        --help) usage; exit 0; ;;
        --wine) in_wine=1 ; shift ; continue ;;
        --fast) fast=1 ; shift ; continue ;;
        default)
            shift
            set -- \
                sanity \
                dedupe-hardlink-tree1 \
                dedupe-hardlink-tree1mtime \
                dedupe-hardlink-tree2 \
                dedupe-hardlink-tree34 \
                dedupe-delete \
                collisions \
                rejects \
                "$@"
            continue
            ;;
        --) opts= ; shift ; continue ;;
        esac
    fi

    src=$1
    shift

    set_tmpdir

    cd "$tmpdir"

    case "$src" in
    sanity)
        echo "# Testing $src in $tmpdir ..."

        check "find-tree1" tree1 "" self find --porcelain test <<EOF
900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663 f one/1
f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127 f one/a2
83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7 f one/b3
ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c f one/c4
6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b l one/l1
900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663 f t2wo/d5
f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127 f t2wo/de6z
83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7 f t2wo/def7
900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663 l t2wo/l2
900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663 f t3hree/8x
f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127 f t3hree/g9xz
900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663 l t3hree/l3
900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663 f t3hree/xfour/ghjkl10xyz
EOF

        replace_a() {
            # replace a regular file with a directory
            rm test/one/1
            mkdir test/one/1
            make_regular test/one/1/xyz "2003-01-01 00:00:00" "xyz"

            # a symlink with a regular file
            rm test/one/l1
            make_regular test/one/l1 "2003-01-01 00:00:00" "nya"

            # a directory with a symlink
            rm -r test/t3hree
            make_symlink test/t3hree "2003-01-01 00:00:01" "nya"

            make_regular test/u4our "2004-01-01 00:00:01" "text 22"
        }

        check "index-tree1-replace-a" tree1 replace_a self index --verbose test <<EOF
rm one/1
add one/1/xyz
update one/l1
add t3hree
rm t3hree/8x
rm t3hree/g9xz
rm t3hree/l3
rm t3hree/xfour/ghjkl10xyz
add u4our
# dir diff
-one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+one/1/ dir mode 700 mtime [2010-01-01 00:00:00]
+one/1/xyz reg mode 600 mtime [2003-01-01 00:00:00] size 3 sha256 3608bca1e44ea6c4d268eb6db02260269892c0b42b86bbf1e77a6fa16c3c9282
-one/l1 sym mode 777 mtime [2001-01-01 00:00:01] -> 1
+one/l1 reg mode 600 mtime [2003-01-01 00:00:00] size 3 sha256 e7a00e53bd04bf48c4cde300b11f10decee18d7a825502c4edcbc2fa38f7fa1f
-t3hree/ dir mode 700 mtime [2010-01-01 00:00:00]
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
-t3hree/xfour/ dir mode 700 mtime [2010-01-01 00:00:00]
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree sym mode 777 mtime [2003-01-01 00:00:01] -> nya
+u4our reg mode 600 mtime [2004-01-01 00:00:01] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
EOF

        subcheck self find --porcelain test <<EOF
3608bca1e44ea6c4d268eb6db02260269892c0b42b86bbf1e77a6fa16c3c9282 f one/1/xyz
f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127 f one/a2
83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7 f one/b3
ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c f one/c4
e7a00e53bd04bf48c4cde300b11f10decee18d7a825502c4edcbc2fa38f7fa1f f one/l1
900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663 f t2wo/d5
f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127 f t2wo/de6z
83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7 f t2wo/def7
900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663 l t2wo/l2
e7a00e53bd04bf48c4cde300b11f10decee18d7a825502c4edcbc2fa38f7fa1f l t3hree
f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127 f u4our
EOF

        check "fsck-tree1-noop" tree1 "" self fsck --verbose test <<EOF
ok one/1
ok one/a2
ok one/b3
ok one/c4
ok one/l1
ok t2wo/d5
ok t2wo/de6z
ok t2wo/def7
ok t2wo/l2
ok t3hree/8x
ok t3hree/g9xz
ok t3hree/l3
ok t3hree/xfour/ghjkl10xyz
EOF

        check "fsck-tree1-touched" tree1 'touch -d "2001-01-01 00:00:00" test/one/c4' self fsck --verbose test <<EOF
ok one/1
ok one/a2
ok one/b3
hoardy:warning: wrong mtime: [2001-01-01 00:00:04.000000000] -> [2001-01-01 00:00:00.000000000]: \`one/c4\`
ok one/c4
ok one/l1
ok t2wo/d5
ok t2wo/de6z
ok t2wo/def7
ok t2wo/l2
ok t3hree/8x
ok t3hree/g9xz
ok t3hree/l3
ok t3hree/xfour/ghjkl10xyz
hoardy:warning: There was 1 warning!
# dir diff
-one/c4 reg mode 600 mtime [2001-01-01 00:00:04] size 9 sha256 ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c
+one/c4 reg mode 600 mtime [2001-01-01 00:00:00] size 9 sha256 ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c
EOF

        subcheck self fsck --verbose --ignore-meta test <<EOF
ok one/1
ok one/a2
ok one/b3
hoardy:warning: wrong mtime: [2001-01-01 00:00:04.000000000] -> [2001-01-01 00:00:00.000000000]: \`one/c4\`
ok one/c4
ok one/l1
ok t2wo/d5
ok t2wo/de6z
ok t2wo/def7
ok t2wo/l2
ok t3hree/8x
ok t3hree/g9xz
ok t3hree/l3
ok t3hree/xfour/ghjkl10xyz
hoardy:warning: There was 1 warning!
EOF

        check "fsck-tree1-corrupted-a" tree1 'make_regular test/one/c4 "2001-01-01 00:00:04" "corrupt"' self fsck --verbose --no-checksum test <<EOF
ok one/1
ok one/a2
ok one/b3
hoardy:error: wrong size: 9 -> 7: \`one/c4\`
hoardy:error: wrong sha256: ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c -> 11d510e067d2cdcd7559bd86d27a2f4c20babd43670346b97af99b522c1f0075: \`one/c4\`
fail one/c4
ok one/l1
ok t2wo/d5
ok t2wo/de6z
ok t2wo/def7
ok t2wo/l2
ok t3hree/8x
ok t3hree/g9xz
ok t3hree/l3
ok t3hree/xfour/ghjkl10xyz
hoardy:error: There were 2 errors!
# \$? == 1
# dir diff
-one/c4 reg mode 600 mtime [2001-01-01 00:00:04] size 9 sha256 ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c
+one/c4 reg mode 600 mtime [2001-01-01 00:00:04] size 7 sha256 11d510e067d2cdcd7559bd86d27a2f4c20babd43670346b97af99b522c1f0075
EOF

        check "fsck-tree1-corrupted-b" tree1 'make_regular test/one/c4 "2001-01-01 00:00:04" "corrupt44"' self fsck --verbose --no-checksum test <<EOF
ok one/1
ok one/a2
ok one/b3
ok one/c4
ok one/l1
ok t2wo/d5
ok t2wo/de6z
ok t2wo/def7
ok t2wo/l2
ok t3hree/8x
ok t3hree/g9xz
ok t3hree/l3
ok t3hree/xfour/ghjkl10xyz
# dir diff
-one/c4 reg mode 600 mtime [2001-01-01 00:00:04] size 9 sha256 ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c
+one/c4 reg mode 600 mtime [2001-01-01 00:00:04] size 9 sha256 0a80a8b0136c4a472fa2406d9852897ea948f0764bb7fa49ff53fa696046c11b
EOF

        subcheck self fsck --verbose test <<EOF
ok one/1
ok one/a2
ok one/b3
hoardy:error: wrong sha256: ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c -> 0a80a8b0136c4a472fa2406d9852897ea948f0764bb7fa49ff53fa696046c11b: \`one/c4\`
fail one/c4
ok one/l1
ok t2wo/d5
ok t2wo/de6z
ok t2wo/def7
ok t2wo/l2
ok t3hree/8x
ok t3hree/g9xz
ok t3hree/l3
ok t3hree/xfour/ghjkl10xyz
hoardy:error: There was 1 error!
# \$? == 1
EOF

        check "fsck-tree1-corrupted-c" tree1 'make_regular test/one/l1 "2001-01-01 00:00:02" "changed"' self fsck --verbose --ignore-meta test <<EOF
ok one/1
ok one/a2
ok one/b3
ok one/c4
hoardy:error: wrong type: l -> f: \`one/l1\`
hoardy:error: wrong size: 1 -> 7: \`one/l1\`
hoardy:warning: wrong mtime: [2001-01-01 00:00:01.000000000] -> [2001-01-01 00:00:02.000000000]: \`one/l1\`
hoardy:error: wrong sha256: 6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b -> d67e2e944994496c8d8ec76eed0cf9f09679448d584b532bebf941852a37f5ed: \`one/l1\`
hoardy:warning: wrong mode: 777 -> 600: \`one/l1\`
fail one/l1
ok t2wo/d5
ok t2wo/de6z
ok t2wo/def7
ok t2wo/l2
ok t3hree/8x
ok t3hree/g9xz
ok t3hree/l3
ok t3hree/xfour/ghjkl10xyz
hoardy:warning: There were 2 warnings!
hoardy:error: There were 3 errors!
# \$? == 1
# dir diff
-one/l1 sym mode 777 mtime [2001-01-01 00:00:01] -> 1
+one/l1 reg mode 600 mtime [2001-01-01 00:00:02] size 7 sha256 d67e2e944994496c8d8ec76eed0cf9f09679448d584b532bebf941852a37f5ed
EOF

        check "find-dupes-tree1-a" tree1 "" self find-dupes --min-inodes 1 test <<EOF
t2wo/def7
one/b3

t2wo/de6z
one/a2
t3hree/g9xz

t3hree/l3
t2wo/l2

t2wo/d5
one/1
t3hree/8x
t3hree/xfour/ghjkl10xyz

EOF

        subcheck self find-dupes test <<EOF
t2wo/def7
one/b3

t2wo/de6z
one/a2
t3hree/g9xz

t3hree/l3
t2wo/l2

t2wo/d5
one/1
t3hree/8x
t3hree/xfour/ghjkl10xyz

EOF

        subcheck self find-dupes --order-inodes abspath --min-inodes 1 test <<EOF
one/b3
t2wo/def7

one/a2
t2wo/de6z
t3hree/g9xz

t2wo/l2
t3hree/l3

one/1
t2wo/d5
t3hree/8x
t3hree/xfour/ghjkl10xyz

EOF

        subcheck self find-dupes --order-inodes abspath test <<EOF
one/b3
t2wo/def7

one/a2
t2wo/de6z
t3hree/g9xz

t2wo/l2
t3hree/l3

one/1
t2wo/d5
t3hree/8x
t3hree/xfour/ghjkl10xyz

EOF
        ;;

    dedupe-hardlink-tree1)
        echo "# Testing $src in $tmpdir ..."

        check "dedupe-hardlink-tree1-a" tree1 "" self deduplicate test <<EOF
__ t2wo/def7
ln one/b3

__ t2wo/de6z
ln one/a2
ln t3hree/g9xz

__ t3hree/l3
ln t2wo/l2

__ t2wo/d5
ln one/1
ln t3hree/8x
ln t3hree/xfour/ghjkl10xyz

# dir diff
-one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-one/a2 reg mode 600 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-one/b3 reg mode 600 mtime [2001-01-01 00:00:03] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+one/1 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+one/a2 reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+one/b3 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:02] -> text 1
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
+t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/8x ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/8x
EOF

        sanity_noop
        sanity_tree1_find_dupes_boring
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-hardlink-tree1-a-rev" tree1 "" self deduplicate --reverse test <<EOF
__ one/b3
ln t2wo/def7

__ t3hree/g9xz
ln one/a2
ln t2wo/de6z

__ t2wo/l2
ln t3hree/l3

__ t3hree/xfour/ghjkl10xyz
ln t3hree/8x
ln one/1
ln t2wo/d5

# dir diff
-one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-one/a2 reg mode 600 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+one/1 reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+one/a2 reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/8x ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/8x
EOF

        sanity_noop
        sanity_tree1_find_dupes_boring
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-hardlink-tree1-b" tree1 "" self deduplicate --order-inodes abspath test <<EOF
__ one/b3
ln t2wo/def7

__ one/a2
ln t2wo/de6z
ln t3hree/g9xz

__ t2wo/l2
ln t3hree/l3

__ one/1
ln t2wo/d5
ln t3hree/8x
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/8x ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/8x
EOF

        sanity_noop
        sanity_tree1_find_dupes_boring
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-hardlink-tree1-c" tree1 "" self deduplicate test/one test/t2wo <<EOF
__ t2wo/d5
ln one/1

__ t2wo/de6z
ln one/a2

__ t2wo/def7
ln one/b3

# dir diff
-one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-one/a2 reg mode 600 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-one/b3 reg mode 600 mtime [2001-01-01 00:00:03] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+one/1 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+one/a2 reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+one/b3 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
EOF

        subcheck self find-dupes --min-inodes 1 test <<EOF
one/b3
t2wo/def7

one/a2
t2wo/de6z
t3hree/g9xz

t3hree/l3
t2wo/l2

one/1
t2wo/d5
t3hree/8x
t3hree/xfour/ghjkl10xyz

EOF

        subcheck self find-dupes test <<EOF
one/a2
t2wo/de6z
t3hree/g9xz

t3hree/l3
t2wo/l2

one/1
t2wo/d5
t3hree/8x
t3hree/xfour/ghjkl10xyz

EOF

        check "dedupe-hardlink-tree1-d" tree1 "" self deduplicate test/t3hree <<EOF
__ t3hree/8x
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/8x
EOF

        subcheck self find-dupes --min-inodes 1 test <<EOF
t2wo/def7
one/b3

t2wo/de6z
one/a2
t3hree/g9xz

t3hree/l3
t2wo/l2

t2wo/d5
one/1
t3hree/8x
t3hree/xfour/ghjkl10xyz

EOF

        subcheck self find-dupes test <<EOF
t2wo/def7
one/b3

t2wo/de6z
one/a2
t3hree/g9xz

t3hree/l3
t2wo/l2

t2wo/d5
one/1
t3hree/8x
t3hree/xfour/ghjkl10xyz

EOF

        subcheck self deduplicate --order-inodes abspath test <<EOF
__ one/b3
ln t2wo/def7

__ one/a2
ln t2wo/de6z
ln t3hree/g9xz

__ t2wo/l2
ln t3hree/l3

__ one/1
ln t2wo/d5
ln t3hree/8x
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/8x ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
EOF

        sanity_noop
        sanity_tree1_find_dupes_boring
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-hardlink-tree1-e" tree1 "" self deduplicate test/one test/t2wo <<EOF
__ t2wo/d5
ln one/1

__ t2wo/de6z
ln one/a2

__ t2wo/def7
ln one/b3

# dir diff
-one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-one/a2 reg mode 600 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-one/b3 reg mode 600 mtime [2001-01-01 00:00:03] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+one/1 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+one/a2 reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+one/b3 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
EOF

        subcheck self deduplicate --order-inodes abspath test/t3hree <<EOF
__ t3hree/8x
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/8x
EOF

        subcheck self deduplicate test <<EOF
__ one/a2
=> t2wo/de6z
ln t3hree/g9xz

__ t3hree/l3
ln t2wo/l2

__ one/1
=> t2wo/d5
ln t3hree/8x
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:02] -> text 1
+t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/8x ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
EOF

        sanity_noop
        sanity_tree1_find_dupes_boring
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-hardlink-tree1-f" tree1 "" self deduplicate test/one test/t3hree <<EOF
__ one/a2
ln t3hree/g9xz

__ one/1
ln t3hree/8x
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+t3hree/8x ref ==> one/1
+t3hree/g9xz ref ==> one/a2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/8x
EOF

        subcheck self deduplicate test <<EOF
__ t2wo/def7
ln one/b3

__ t2wo/de6z
ln one/a2
ln t3hree/g9xz

__ t3hree/l3
ln t2wo/l2

__ t2wo/d5
ln one/1
ln t3hree/8x
ln t3hree/xfour/ghjkl10xyz

# dir diff
-one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-one/a2 reg mode 600 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-one/b3 reg mode 600 mtime [2001-01-01 00:00:03] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+one/1 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+one/a2 reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+one/b3 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:02] -> text 1
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
+t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
-t3hree/8x ref ==> one/1
-t3hree/g9xz ref ==> one/a2
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/8x ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-hardlink-tree1-g" tree1 "" self deduplicate test/one test/t3hree <<EOF
__ one/a2
ln t3hree/g9xz

__ one/1
ln t3hree/8x
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+t3hree/8x ref ==> one/1
+t3hree/g9xz ref ==> one/a2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/8x
EOF

        subcheck self deduplicate --order-inodes abspath test <<EOF
__ one/b3
ln t2wo/def7

__ one/a2
=> t3hree/g9xz
ln t2wo/de6z

__ t2wo/l2
ln t3hree/l3

__ one/1
=> t3hree/8x
=> t3hree/xfour/ghjkl10xyz
ln t2wo/d5

# dir diff
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
-t3hree/8x ref ==> one/1
-t3hree/g9xz ref ==> one/a2
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/8x ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop
        ;;

    dedupe-hardlink-tree1mtime)
        echo "# Testing $src in $tmpdir ..."

        pre_deduplicate() {
            self deduplicate test/a
            self deduplicate test/b
            self deduplicate test/c
            self deduplicate test/z
        }

        check "dedupe-hardlink-tree1mtime-a" tree1mtime "" pre_deduplicate <<EOF
__ a/one/b3
ln a/t2wo/def7

__ a/one/a2
ln a/t2wo/de6z
ln a/t3hree/g9xz

__ a/t2wo/l2
ln a/t3hree/l3

__ a/one/1
ln a/t2wo/d5
ln a/t3hree/8x
ln a/t3hree/xfour/ghjkl10xyz

__ b/one/b3
ln b/t2wo/def7

__ b/one/a2
ln b/t2wo/de6z
ln b/t3hree/g9xz

__ b/t2wo/l2
ln b/t3hree/l3

__ b/one/1
ln b/t2wo/d5
ln b/t3hree/8x
ln b/t3hree/xfour/ghjkl10xyz

__ c/one/b3
ln c/t2wo/def7

__ c/one/a2
ln c/t2wo/de6z
ln c/t3hree/g9xz

__ c/t2wo/l2
ln c/t3hree/l3

__ c/one/1
ln c/t2wo/d5
ln c/t3hree/8x
ln c/t3hree/xfour/ghjkl10xyz

__ z/one/b3
ln z/t2wo/def7

__ z/one/a2
ln z/t2wo/de6z
ln z/t3hree/g9xz

__ z/t2wo/l2
ln z/t3hree/l3

__ z/one/1
ln z/t2wo/d5
ln z/t3hree/8x
ln z/t3hree/xfour/ghjkl10xyz

# dir diff
-a/t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-a/t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-a/t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:00] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+a/t2wo/d5 ref ==> a/one/1
+a/t2wo/de6z ref ==> a/one/a2
+a/t2wo/def7 ref ==> a/one/b3
-a/t3hree/8x reg mode 600 mtime [2000-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-a/t3hree/g9xz reg mode 600 mtime [2000-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-a/t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:00] -> text 1
+a/t3hree/8x ref ==> a/t2wo/d5
+a/t3hree/g9xz ref ==> a/t2wo/de6z
+a/t3hree/l3 ref ==> a/t2wo/l2
-a/t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2000-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+a/t3hree/xfour/ghjkl10xyz ref ==> a/t3hree/8x
-b/t2wo/d5 reg mode 600 mtime [2001-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-b/t2wo/de6z reg mode 600 mtime [2001-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-b/t2wo/def7 reg mode 600 mtime [2001-01-01 00:00:00] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+b/t2wo/d5 ref ==> b/one/1
+b/t2wo/de6z ref ==> b/one/a2
+b/t2wo/def7 ref ==> b/one/b3
-b/t3hree/8x reg mode 600 mtime [2001-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-b/t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-b/t3hree/l3 sym mode 777 mtime [2001-01-01 00:00:00] -> text 1
+b/t3hree/8x ref ==> b/t2wo/d5
+b/t3hree/g9xz ref ==> b/t2wo/de6z
+b/t3hree/l3 ref ==> b/t2wo/l2
-b/t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+b/t3hree/xfour/ghjkl10xyz ref ==> b/t3hree/8x
-c/t2wo/d5 reg mode 600 mtime [2010-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-c/t2wo/de6z reg mode 600 mtime [2010-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-c/t2wo/def7 reg mode 600 mtime [2010-01-01 00:00:00] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+c/t2wo/d5 ref ==> c/one/1
+c/t2wo/de6z ref ==> c/one/a2
+c/t2wo/def7 ref ==> c/one/b3
-c/t3hree/8x reg mode 600 mtime [2010-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-c/t3hree/g9xz reg mode 600 mtime [2010-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-c/t3hree/l3 sym mode 777 mtime [2010-01-01 00:00:00] -> text 1
+c/t3hree/8x ref ==> c/t2wo/d5
+c/t3hree/g9xz ref ==> c/t2wo/de6z
+c/t3hree/l3 ref ==> c/t2wo/l2
-c/t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2010-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+c/t3hree/xfour/ghjkl10xyz ref ==> c/t3hree/8x
-z/t2wo/d5 reg mode 600 mtime [2010-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-z/t2wo/de6z reg mode 600 mtime [2010-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-z/t2wo/def7 reg mode 600 mtime [2010-01-01 00:00:00] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+z/t2wo/d5 ref ==> z/one/1
+z/t2wo/de6z ref ==> z/one/a2
+z/t2wo/def7 ref ==> z/one/b3
-z/t3hree/8x reg mode 600 mtime [2010-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-z/t3hree/g9xz reg mode 600 mtime [2010-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-z/t3hree/l3 sym mode 777 mtime [2010-01-01 00:00:00] -> text 1
+z/t3hree/8x ref ==> z/t2wo/d5
+z/t3hree/g9xz ref ==> z/t2wo/de6z
+z/t3hree/l3 ref ==> z/t2wo/l2
-z/t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2010-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+z/t3hree/xfour/ghjkl10xyz ref ==> z/t3hree/8x
EOF

        sanity_noop

        subcheck self deduplicate --order-inodes abspath test/a test/z <<EOF
__ a/one/c4
ln z/one/c4

__ a/one/l1
ln z/one/l1

__ a/one/b3
=> a/t2wo/def7
ln z/one/b3
ln z/t2wo/def7

__ a/one/a2
=> a/t2wo/de6z
=> a/t3hree/g9xz
ln z/one/a2
ln z/t2wo/de6z
ln z/t3hree/g9xz

__ a/t2wo/l2
=> a/t3hree/l3
ln z/t2wo/l2
ln z/t3hree/l3

__ a/one/1
=> a/t2wo/d5
=> a/t3hree/8x
=> a/t3hree/xfour/ghjkl10xyz
ln z/one/1
ln z/t2wo/d5
ln z/t3hree/8x
ln z/t3hree/xfour/ghjkl10xyz

# dir diff
-z/one/1 reg mode 600 mtime [2010-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-z/one/a2 reg mode 600 mtime [2010-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-z/one/b3 reg mode 600 mtime [2010-01-01 00:00:00] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-z/one/c4 reg mode 600 mtime [2010-01-01 00:00:00] size 9 sha256 ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c
-z/one/l1 sym mode 777 mtime [2010-01-01 00:00:00] -> 1
+z/one/1 ref ==> a/t3hree/xfour/ghjkl10xyz
+z/one/a2 ref ==> a/t3hree/g9xz
+z/one/b3 ref ==> a/t2wo/def7
+z/one/c4 ref ==> a/one/c4
+z/one/l1 ref ==> a/one/l1
-z/t2wo/l2 sym mode 777 mtime [2010-01-01 00:00:00] -> text 1
+z/t2wo/l2 ref ==> a/t3hree/l3
EOF

        sanity_noop

        subcheck self deduplicate --order-inodes abspath test/b test/z <<EOF
__ b/one/c4
ln z/one/c4

__ b/one/l1
ln z/one/l1

__ b/one/b3
=> b/t2wo/def7
ln z/one/b3
ln z/t2wo/def7

__ b/one/a2
=> b/t2wo/de6z
=> b/t3hree/g9xz
ln z/one/a2
ln z/t2wo/de6z
ln z/t3hree/g9xz

__ b/t2wo/l2
=> b/t3hree/l3
ln z/t2wo/l2
ln z/t3hree/l3

__ b/one/1
=> b/t2wo/d5
=> b/t3hree/8x
=> b/t3hree/xfour/ghjkl10xyz
ln z/one/1
ln z/t2wo/d5
ln z/t3hree/8x
ln z/t3hree/xfour/ghjkl10xyz

# dir diff
-z/one/1 ref ==> a/t3hree/xfour/ghjkl10xyz
-z/one/a2 ref ==> a/t3hree/g9xz
-z/one/b3 ref ==> a/t2wo/def7
-z/one/c4 ref ==> a/one/c4
-z/one/l1 ref ==> a/one/l1
+z/one/1 ref ==> b/t3hree/xfour/ghjkl10xyz
+z/one/a2 ref ==> b/t3hree/g9xz
+z/one/b3 ref ==> b/t2wo/def7
+z/one/c4 ref ==> b/one/c4
+z/one/l1 ref ==> b/one/l1
-z/t2wo/l2 ref ==> a/t3hree/l3
+z/t2wo/l2 ref ==> b/t3hree/l3
EOF

        subcheck self deduplicate --order-inodes abspath test/c test/z <<EOF
__ c/one/c4
ln z/one/c4

__ c/one/l1
ln z/one/l1

__ c/one/b3
=> c/t2wo/def7
ln z/one/b3
ln z/t2wo/def7

__ c/one/a2
=> c/t2wo/de6z
=> c/t3hree/g9xz
ln z/one/a2
ln z/t2wo/de6z
ln z/t3hree/g9xz

__ c/t2wo/l2
=> c/t3hree/l3
ln z/t2wo/l2
ln z/t3hree/l3

__ c/one/1
=> c/t2wo/d5
=> c/t3hree/8x
=> c/t3hree/xfour/ghjkl10xyz
ln z/one/1
ln z/t2wo/d5
ln z/t3hree/8x
ln z/t3hree/xfour/ghjkl10xyz

# dir diff
-z/one/1 ref ==> b/t3hree/xfour/ghjkl10xyz
-z/one/a2 ref ==> b/t3hree/g9xz
-z/one/b3 ref ==> b/t2wo/def7
-z/one/c4 ref ==> b/one/c4
-z/one/l1 ref ==> b/one/l1
+z/one/1 ref ==> c/t3hree/xfour/ghjkl10xyz
+z/one/a2 ref ==> c/t3hree/g9xz
+z/one/b3 ref ==> c/t2wo/def7
+z/one/c4 ref ==> c/one/c4
+z/one/l1 ref ==> c/one/l1
-z/t2wo/l2 ref ==> b/t3hree/l3
+z/t2wo/l2 ref ==> c/t3hree/l3
EOF

        sanity_noop

        check "dedupe-hardlink-tree1mtime-b" tree1mtime "" self deduplicate --order-inodes argno test/c test/b <<EOF
__ c/one/c4
ln b/one/c4

__ c/one/l1
ln b/one/l1

__ c/one/b3
ln c/t2wo/def7
ln b/one/b3
ln b/t2wo/def7

__ c/one/a2
ln c/t2wo/de6z
ln c/t3hree/g9xz
ln b/one/a2
ln b/t2wo/de6z
ln b/t3hree/g9xz

__ c/t2wo/l2
ln c/t3hree/l3
ln b/t2wo/l2
ln b/t3hree/l3

__ c/one/1
ln c/t2wo/d5
ln c/t3hree/8x
ln c/t3hree/xfour/ghjkl10xyz
ln b/one/1
ln b/t2wo/d5
ln b/t3hree/8x
ln b/t3hree/xfour/ghjkl10xyz

# dir diff
-b/one/1 reg mode 600 mtime [2001-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-b/one/a2 reg mode 600 mtime [2001-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-b/one/b3 reg mode 600 mtime [2001-01-01 00:00:00] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-b/one/c4 reg mode 600 mtime [2001-01-01 00:00:00] size 9 sha256 ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c
-b/one/l1 sym mode 777 mtime [2001-01-01 00:00:00] -> 1
+b/one/1 reg mode 600 mtime [2010-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+b/one/a2 reg mode 600 mtime [2010-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+b/one/b3 reg mode 600 mtime [2010-01-01 00:00:00] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+b/one/c4 reg mode 600 mtime [2010-01-01 00:00:00] size 9 sha256 ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c
+b/one/l1 sym mode 777 mtime [2010-01-01 00:00:00] -> 1
-b/t2wo/d5 reg mode 600 mtime [2001-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-b/t2wo/de6z reg mode 600 mtime [2001-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-b/t2wo/def7 reg mode 600 mtime [2001-01-01 00:00:00] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-b/t2wo/l2 sym mode 777 mtime [2001-01-01 00:00:00] -> text 1
+b/t2wo/d5 ref ==> b/one/1
+b/t2wo/de6z ref ==> b/one/a2
+b/t2wo/def7 ref ==> b/one/b3
+b/t2wo/l2 sym mode 777 mtime [2010-01-01 00:00:00] -> text 1
-b/t3hree/8x reg mode 600 mtime [2001-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-b/t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-b/t3hree/l3 sym mode 777 mtime [2001-01-01 00:00:00] -> text 1
+b/t3hree/8x ref ==> b/t2wo/d5
+b/t3hree/g9xz ref ==> b/t2wo/de6z
+b/t3hree/l3 ref ==> b/t2wo/l2
-b/t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+b/t3hree/xfour/ghjkl10xyz ref ==> b/t3hree/8x
-c/one/1 reg mode 600 mtime [2010-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-c/one/a2 reg mode 600 mtime [2010-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-c/one/b3 reg mode 600 mtime [2010-01-01 00:00:00] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-c/one/c4 reg mode 600 mtime [2010-01-01 00:00:00] size 9 sha256 ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c
-c/one/l1 sym mode 777 mtime [2010-01-01 00:00:00] -> 1
+c/one/1 ref ==> b/t3hree/xfour/ghjkl10xyz
+c/one/a2 ref ==> b/t3hree/g9xz
+c/one/b3 ref ==> b/t2wo/def7
+c/one/c4 ref ==> b/one/c4
+c/one/l1 ref ==> b/one/l1
-c/t2wo/d5 reg mode 600 mtime [2010-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-c/t2wo/de6z reg mode 600 mtime [2010-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-c/t2wo/def7 reg mode 600 mtime [2010-01-01 00:00:00] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-c/t2wo/l2 sym mode 777 mtime [2010-01-01 00:00:00] -> text 1
+c/t2wo/d5 ref ==> c/one/1
+c/t2wo/de6z ref ==> c/one/a2
+c/t2wo/def7 ref ==> c/one/b3
+c/t2wo/l2 ref ==> b/t3hree/l3
-c/t3hree/8x reg mode 600 mtime [2010-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-c/t3hree/g9xz reg mode 600 mtime [2010-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-c/t3hree/l3 sym mode 777 mtime [2010-01-01 00:00:00] -> text 1
+c/t3hree/8x ref ==> c/t2wo/d5
+c/t3hree/g9xz ref ==> c/t2wo/de6z
+c/t3hree/l3 ref ==> c/t2wo/l2
-c/t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2010-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+c/t3hree/xfour/ghjkl10xyz ref ==> c/t3hree/8x
EOF

        ;;

    dedupe-hardlink-tree2)
        echo "# Testing $src in $tmpdir ..."

        check "dedupe-hardlink-tree2-a" tree2 "" self deduplicate test/one test/t3hree <<EOF
__ one/a2
ln t3hree/g9xz

__ one/1
ln t3hree/0
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t3hree/0 reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+t3hree/0 ref ==> one/1
+t3hree/g9xz ref ==> one/a2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/0
EOF

        subcheck self deduplicate --order-paths basename test <<EOF
__ t2wo/def7
ln one/b3

__ t2wo/de6z
ln one/a2
ln t3hree/g9xz

__ t3hree/l3
ln t2wo/l2

__ t2wo/d5
ln t3hree/0
ln one/1
ln t3hree/xfour/ghjkl10xyz

# dir diff
-one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-one/a2 reg mode 600 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-one/b3 reg mode 600 mtime [2001-01-01 00:00:03] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+one/1 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+one/a2 reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+one/b3 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:02] -> text 1
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
+t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
-t3hree/0 ref ==> one/1
-t3hree/g9xz ref ==> one/a2
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/0 ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-hardlink-tree2-b" tree2 "" self deduplicate --order-inodes abspath test/one test/t3hree <<EOF
__ one/a2
ln t3hree/g9xz

__ one/1
ln t3hree/0
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t3hree/0 reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+t3hree/0 ref ==> one/1
+t3hree/g9xz ref ==> one/a2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/0
EOF

        subcheck self deduplicate --order-inodes abspath --order-paths basename test <<EOF
__ one/b3
ln t2wo/def7

__ one/a2
=> t3hree/g9xz
ln t2wo/de6z

__ t2wo/l2
ln t3hree/l3

__ t3hree/0
=> one/1
=> t3hree/xfour/ghjkl10xyz
ln t2wo/d5

# dir diff
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
-t3hree/0 ref ==> one/1
-t3hree/g9xz ref ==> one/a2
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/0 ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-hardlink-tree2-c" tree2 "" self deduplicate --order-inodes dirname test/one test/t3hree <<EOF
__ one/a2
ln t3hree/g9xz

__ one/1
ln t3hree/0
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t3hree/0 reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+t3hree/0 ref ==> one/1
+t3hree/g9xz ref ==> one/a2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/0
EOF

        subcheck self deduplicate --order-inodes abspath --order-paths basename test <<EOF
__ one/b3
ln t2wo/def7

__ one/a2
=> t3hree/g9xz
ln t2wo/de6z

__ t2wo/l2
ln t3hree/l3

__ t3hree/0
=> one/1
=> t3hree/xfour/ghjkl10xyz
ln t2wo/d5

# dir diff
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
-t3hree/0 ref ==> one/1
-t3hree/g9xz ref ==> one/a2
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/0 ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-hardlink-tree2-d" tree2 "" self deduplicate --order-inodes basename test <<EOF
__ one/b3
ln t2wo/def7

__ one/a2
ln t2wo/de6z
ln t3hree/g9xz

__ t2wo/l2
ln t3hree/l3

__ t3hree/0
ln one/1
ln t2wo/d5
ln t3hree/xfour/ghjkl10xyz

# dir diff
-one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+one/1 reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
-t3hree/0 reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/0 ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/0
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-hardlink-tree2-d-rev" tree2 "" self deduplicate --reverse --order-inodes basename test <<EOF
__ t2wo/def7
ln one/b3

__ t3hree/g9xz
ln t2wo/de6z
ln one/a2

__ t3hree/l3
ln t2wo/l2

__ t3hree/xfour/ghjkl10xyz
ln t2wo/d5
ln one/1
ln t3hree/0

# dir diff
-one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-one/a2 reg mode 600 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-one/b3 reg mode 600 mtime [2001-01-01 00:00:03] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+one/1 reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+one/a2 reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+one/b3 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:02] -> text 1
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
+t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
-t3hree/0 reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/0 ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/0
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop
        ;;

    dedupe-hardlink-tree34)
        echo "# Testing $src in $tmpdir ..."

        check "dedupe-hardlink-tree3-a" tree3 "" self deduplicate test <<EOF
__ t2wo/de6z
ln t3hree/g9xz

__ t3hree/l3
ln t2wo/l2

__ t2wo/d5
ln t3hree/8x
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:02] -> text 1
+t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/8x ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/8x
EOF

        sanity_noop

        subcheck self deduplicate --ignore-perms test <<EOF
__ t2wo/def7
ln one/b3

__ t2wo/de6z
=> t3hree/g9xz
ln one/a2

__ t2wo/d5
=> t3hree/8x
=> t3hree/xfour/ghjkl10xyz
ln one/1

# dir diff
-one/1 reg mode 400 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-one/a2 reg mode 400 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-one/b3 reg mode 400 mtime [2001-01-01 00:00:03] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+one/1 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+one/a2 reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+one/b3 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-hardlink-tree3-b" tree3 "" self deduplicate test <<EOF
__ t2wo/de6z
ln t3hree/g9xz

__ t3hree/l3
ln t2wo/l2

__ t2wo/d5
ln t3hree/8x
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:02] -> text 1
+t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/8x ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/8x
EOF

        sanity_noop

        subcheck self deduplicate --order-inodes abspath --ignore-perms test <<EOF
__ one/b3
ln t2wo/def7

__ one/a2
ln t2wo/de6z
ln t3hree/g9xz

__ one/1
ln t2wo/d5
ln t3hree/8x
ln t3hree/xfour/ghjkl10xyz

# dir diff
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-hardlink-tree4-a" tree4 "" self deduplicate test <<EOF
__ v1/one/c4
ln v2/one/c4

__ v1/one/l1
ln v2/one/l1

__ v1/t2wo/def7
ln v1/one/b3
ln v2/one/b3
ln v2/t2wo/def7

__ v1/t2wo/de6z
ln v1/one/a2
ln v1/t3hree/g9xz
ln v2/one/a2
ln v2/t2wo/de6z
ln v2/t3hree/g9xz

__ v1/t3hree/l3
ln v1/t2wo/l2
ln v2/t2wo/l2
ln v2/t3hree/l3

__ v1/t2wo/d5
ln v1/one/1
ln v1/t3hree/8x
ln v1/t3hree/xfour/ghjkl10xyz
ln v2/one/1
ln v2/t2wo/d5
ln v2/t3hree/0
ln v2/t3hree/xfour/ghjkl10xyz

# dir diff
-v1/one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-v1/one/a2 reg mode 600 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-v1/one/b3 reg mode 600 mtime [2001-01-01 00:00:03] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+v1/one/1 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+v1/one/a2 reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+v1/one/b3 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-v1/t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-v1/t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-v1/t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-v1/t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:02] -> text 1
+v1/t2wo/d5 ref ==> v1/one/1
+v1/t2wo/de6z ref ==> v1/one/a2
+v1/t2wo/def7 ref ==> v1/one/b3
+v1/t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
-v1/t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-v1/t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-v1/t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+v1/t3hree/8x ref ==> v1/t2wo/d5
+v1/t3hree/g9xz ref ==> v1/t2wo/de6z
+v1/t3hree/l3 ref ==> v1/t2wo/l2
-v1/t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+v1/t3hree/xfour/ghjkl10xyz ref ==> v1/t3hree/8x
-v2/one/1 reg mode 600 mtime [2002-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-v2/one/a2 reg mode 600 mtime [2002-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-v2/one/b3 reg mode 600 mtime [2002-01-01 00:00:00] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-v2/one/c4 reg mode 600 mtime [2002-01-01 00:00:00] size 9 sha256 ef8af0f1d80ae96d3d101a0821d2609bb6b0479b10dcef08d6c0b8d2624cca6c
-v2/one/l1 sym mode 777 mtime [2003-01-01 00:00:00] -> 1
+v2/one/1 ref ==> v1/t3hree/xfour/ghjkl10xyz
+v2/one/a2 ref ==> v1/t3hree/g9xz
+v2/one/b3 ref ==> v1/t2wo/def7
+v2/one/c4 ref ==> v1/one/c4
+v2/one/l1 ref ==> v1/one/l1
-v2/t2wo/d5 reg mode 600 mtime [2002-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-v2/t2wo/de6z reg mode 600 mtime [2002-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-v2/t2wo/def7 reg mode 600 mtime [2002-01-01 00:00:00] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-v2/t2wo/l2 sym mode 777 mtime [2003-01-01 00:00:00] -> text 1
+v2/t2wo/d5 ref ==> v2/one/1
+v2/t2wo/de6z ref ==> v2/one/a2
+v2/t2wo/def7 ref ==> v2/one/b3
+v2/t2wo/l2 ref ==> v1/t3hree/l3
-v2/t3hree/0 reg mode 600 mtime [2002-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-v2/t3hree/g9xz reg mode 600 mtime [2002-01-01 00:00:00] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-v2/t3hree/l3 sym mode 777 mtime [2003-01-01 00:00:00] -> text 1
+v2/t3hree/0 ref ==> v2/t2wo/d5
+v2/t3hree/g9xz ref ==> v2/t2wo/de6z
+v2/t3hree/l3 ref ==> v2/t2wo/l2
-v2/t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2002-01-01 00:00:00] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+v2/t3hree/xfour/ghjkl10xyz ref ==> v2/t3hree/0
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop
        ;;

    dedupe-delete)
        echo "# Testing $src in $tmpdir ..."

        check "dedupe-delete-tree1-a" tree1 "" self deduplicate --delete test <<EOF
__ t2wo/def7
rm one/b3

__ t2wo/de6z
rm one/a2
rm t3hree/g9xz

__ t3hree/l3
rm t2wo/l2

__ t2wo/d5
rm one/1
rm t3hree/8x
rm t3hree/xfour/ghjkl10xyz

# dir diff
-one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-one/a2 reg mode 600 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-one/b3 reg mode 600 mtime [2001-01-01 00:00:03] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:02] -> text 1
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-delete-tree1-b" tree1 "" self deduplicate --delete --order-inodes abspath test <<EOF
__ one/b3
rm t2wo/def7

__ one/a2
rm t2wo/de6z
rm t3hree/g9xz

__ t2wo/l2
rm t3hree/l3

__ one/1
rm t2wo/d5
rm t3hree/8x
rm t3hree/xfour/ghjkl10xyz

# dir diff
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-delete-tree3-a" tree3 "" self deduplicate --delete test <<EOF
__ t2wo/de6z
rm t3hree/g9xz

__ t3hree/l3
rm t2wo/l2

__ t2wo/d5
rm t3hree/8x
rm t3hree/xfour/ghjkl10xyz

# dir diff
-t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:02] -> text 1
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
EOF

        sanity_noop

        subcheck self deduplicate --delete --ignore-perms test <<EOF
__ t2wo/d5
rm one/1

__ t2wo/de6z
rm one/a2

__ t2wo/def7
rm one/b3

# dir diff
-one/1 reg mode 400 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-one/a2 reg mode 400 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-one/b3 reg mode 400 mtime [2001-01-01 00:00:03] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop

        check "dedupe-delete-tree3-b" tree3 "" self deduplicate --delete --order-inodes abspath test <<EOF
__ t2wo/de6z
rm t3hree/g9xz

__ t2wo/l2
rm t3hree/l3

__ t2wo/d5
rm t3hree/8x
rm t3hree/xfour/ghjkl10xyz

# dir diff
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
EOF

        sanity_noop

        subcheck self deduplicate --delete --order-inodes abspath --ignore-perms test <<EOF
__ one/1
rm t2wo/d5

__ one/a2
rm t2wo/de6z

__ one/b3
rm t2wo/def7

# dir diff
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
EOF

        sanity_noop
        sanity_empty_find_dupes
        sanity_noop_deduplicate
        sanity_noop
        ;;

    collisions)
        echo "# Testing hash collisions in $tmpdir ..."

        debug_args=(--debug-hash-len 1)

        check "find-tree1collide" tree1collide "" self find --porcelain test <<EOF
90 f one/1
f3 f one/a2
83 f one/b3
ef f one/c4
6b l one/l1
90 f t2wo/d5
f3 f t2wo/de6z
83 f t2wo/def7
90 l t2wo/l2
90 f t3hree/8x
f3 f t3hree/g9xz
90 l t3hree/l3
90 f t3hree/xfour/ghjkl10xyz
90 f xcollide/1
EOF

        check "fsck-tree1collide-noop" tree1collide "" self fsck --verbose test <<EOF
ok one/1
ok one/a2
ok one/b3
ok one/c4
ok one/l1
ok t2wo/d5
ok t2wo/de6z
ok t2wo/def7
ok t2wo/l2
ok t3hree/8x
ok t3hree/g9xz
ok t3hree/l3
ok t3hree/xfour/ghjkl10xyz
ok xcollide/1
EOF

        check "deduplicate-tree1collide-a" tree1collide "" self deduplicate --ignore-size test <<EOF
__ t2wo/def7
ln one/b3

__ t2wo/de6z
ln one/a2
ln t3hree/g9xz

__ t3hree/l3
ln t2wo/l2

__ t2wo/d5
ln one/1
hoardy:error: skipping: collision: sha256 is \`90\` while
hoardy:error: file   \`t2wo/d5\`
hoardy:error: is not \`xcollide/1\`
fail xcollide/1
ln t3hree/8x
ln t3hree/xfour/ghjkl10xyz

hoardy:error: There was 1 error!
# \$? == 1
# dir diff
-one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-one/a2 reg mode 600 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-one/b3 reg mode 600 mtime [2001-01-01 00:00:03] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
+one/1 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+one/a2 reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
+one/b3 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/d5 reg mode 600 mtime [2000-01-01 00:00:05] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t2wo/de6z reg mode 600 mtime [2000-01-01 00:00:06] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t2wo/def7 reg mode 600 mtime [2000-01-01 00:00:07] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:02] -> text 1
+t2wo/d5 ref ==> one/1
+t2wo/de6z ref ==> one/a2
+t2wo/def7 ref ==> one/b3
+t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/l3 sym mode 777 mtime [2000-01-01 00:00:01] -> text 1
+t3hree/8x ref ==> t2wo/d5
+t3hree/g9xz ref ==> t2wo/de6z
+t3hree/l3 ref ==> t2wo/l2
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
+t3hree/xfour/ghjkl10xyz ref ==> t3hree/8x
EOF

        sanity_noop

        subcheck self find-dupes test <<EOF
EOF

        subcheck self find-dupes --ignore-size test <<EOF
one/1
t2wo/d5
t3hree/8x
t3hree/xfour/ghjkl10xyz
xcollide/1

EOF

        subcheck self find-dupes --min-inodes 1 --min-paths 1 test <<EOF
one/c4

one/l1

one/b3
t2wo/def7

one/a2
t2wo/de6z
t3hree/g9xz

t2wo/l2
t3hree/l3

one/1
t2wo/d5
t3hree/8x
t3hree/xfour/ghjkl10xyz

xcollide/1

EOF

        sanity_noop

        debug_args=()
        ;;

    rejects)
        echo "# Testing rejected operations in $tmpdir ..."

        check "dedupe-no-delete-a" tree1 "" self deduplicate --delete test/one test/one <<EOF
hoardy:warning: ignored a repeated path: \`INPUT\`s #0 (\`one\`) and #1 (\`one\`) both contain path \`one/1\`
hoardy:warning: ignored a repeated path: \`INPUT\`s #0 (\`one\`) and #1 (\`one\`) both contain path \`one/a2\`
hoardy:warning: ignored a repeated path: \`INPUT\`s #0 (\`one\`) and #1 (\`one\`) both contain path \`one/b3\`
hoardy:warning: ignored a repeated path: \`INPUT\`s #0 (\`one\`) and #1 (\`one\`) both contain path \`one/c4\`
hoardy:warning: ignored a repeated path: \`INPUT\`s #0 (\`one\`) and #1 (\`one\`) both contain path \`one/l1\`
hoardy:warning: There were 5 warnings!
EOF

        check "dedupe-no-delete-b" tree1 'ln -s t3hree test/five; touch -h -d "2002-01-01 00:00:00" test/five' self deduplicate --delete test/t3hree/xfour test/five/xfour <<EOF
hoardy:warning: ignored a repeated path: \`INPUT\`s #0 (\`t3hree/xfour\`) and #1 (\`t3hree/xfour\`) both contain path \`t3hree/xfour/ghjkl10xyz\`
hoardy:warning: There was 1 warning!
# dir diff
+five sym mode 777 mtime [2002-01-01 00:00:00] -> t3hree
EOF
        ;;

    super-rejects)
        echo "# Testing rejected operations requiring super-user permissions in $tmpdir ..."

        mount_bind() {
            mkdir test/xbind
            mount --bind test/one test/xbind
        }

        check "dedupe-no-delete-a" tree1 mount_bind self index test <<EOF
# dir diff
+xbind ref ==> one
+xbind/1 ref ==> one/1
+xbind/a2 ref ==> one/a2
+xbind/b3 ref ==> one/b3
+xbind/c4 ref ==> one/c4
+xbind/l1 ref ==> one/l1
EOF

        subcheck self deduplicate --delete test <<EOF
__ t3hree/l3
rm t2wo/l2

__ t2wo/d5
rm one/1
hoardy:error: \`same_data\` failed: [Errno 2, ENOENT] No such file or directory: xbind/1
hoardy:error: skipping deduplication: broken target: \`xbind/1\`
fail xbind/1
rm t3hree/8x
rm t3hree/xfour/ghjkl10xyz

__ t2wo/de6z
rm one/a2
hoardy:error: \`same_data\` failed: [Errno 2, ENOENT] No such file or directory: xbind/a2
hoardy:error: skipping deduplication: broken target: \`xbind/a2\`
fail xbind/a2
rm t3hree/g9xz

__ t2wo/def7
rm one/b3
hoardy:error: \`same_data\` failed: [Errno 2, ENOENT] No such file or directory: xbind/b3
hoardy:error: skipping deduplication: broken target: \`xbind/b3\`
fail xbind/b3

__ one/c4
hoardy:error: skipping deduplication: source and target are different paths for the same inode with \`nlink == 1\`:
hoardy:error: \`one/c4\`
hoardy:error: \`xbind/c4\`
hoardy:error: is this a \`mount --bind\`?
fail xbind/c4

__ one/l1
hoardy:error: skipping deduplication: source and target are different paths for the same inode with \`nlink == 1\`:
hoardy:error: \`one/l1\`
hoardy:error: \`xbind/l1\`
hoardy:error: is this a \`mount --bind\`?
fail xbind/l1

hoardy:error: There were 8 errors!
# \$? == 1
# dir diff
-one/1 reg mode 600 mtime [2001-01-01 00:00:01] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-one/a2 reg mode 600 mtime [2001-01-01 00:00:02] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-one/b3 reg mode 600 mtime [2001-01-01 00:00:03] size 8 sha256 83e2772f0ff8340fa4fd262c3bafa5217ec67b79c9ba5e83fb6a09f216ccced7
-t2wo/l2 sym mode 777 mtime [2000-01-01 00:00:02] -> text 1
-t3hree/8x reg mode 600 mtime [2001-01-01 00:00:08] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-t3hree/g9xz reg mode 600 mtime [2001-01-01 00:00:09] size 7 sha256 f377291a5158a26bcb4e5450e061750693129dc5d912e8e8a0e1cce43b3f5127
-t3hree/xfour/ghjkl10xyz reg mode 600 mtime [2001-01-01 00:00:10] size 6 sha256 900a4469df00ccbfd0c145c6d1e4b7953dd0afafadd7534e3a4019e8d38fc663
-xbind/1 ref ==> one/1
-xbind/a2 ref ==> one/a2
-xbind/b3 ref ==> one/b3
EOF

        umount "$tmpdir/$current_target/test/xbind"
        ;;

    *)
        echo "# Testing fixed-outputness on $src in $tmpdir ..."

        start import
        cp -a "$src" "test"
        end

        start index
        set_subtree_dir_mtimes test "2010-01-01 00:00:00"
        describe-forest --modes --mtimes test > describe-dir.old
        ok_no_stderr self index --verbose test
        end

        sanity_noop

        start find
        fixed_stdio "$src" hoardy.find self find --porcelain test
        end

        sanity_noop

        start find-dupes
        fixed_stdio "$src" hoardy.find-dupes self find-dupes test
        end

        sanity_noop

        start deduplicate
        fixed_stdio "$src" hoardy.deduplicate.mtime self deduplicate test
        set_subtree_dir_mtimes test "2010-01-01 00:00:00"
        describe-forest --modes --mtimes test > hoardy.deduplicate.describe-dir
        fixed_file "$src" hoardy.deduplicate.describe-dir
        end

        mv hoardy.deduplicate.describe-dir describe-dir.old
        sanity_noop
        ;;
    esac

    cd /
    rm -rf "$tmpdir"
done

finish
