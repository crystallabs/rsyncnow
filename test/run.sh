#!/usr/bin/env bash
#
# Test suite for rsyncnow.
#
# Most of the tests run rsyncnow and plain `rsync -a` with the same SRC and
# DST arguments, each in its own copy of a small directory tree, and then
# check that both have produced the same files and the same exit status.
#
# Usage: test/run.sh [-k] [GROUP|TEST...]
#
#   -k      - Keep the work directory (its path is printed at the end)
#   GROUP   - Run only the tests from that group (local, ssh, daemon, extra)
#   TEST    - Run only that test (e.g. L02)
#
# Groups:
#   local   - Local sources and destinations
#   ssh     - Remote sources and destinations, using ssh to localhost. Skipped
#             if `ssh localhost` doesn't work without a password or a prompt.
#             A temporary directory is created in $HOME for these tests.
#   daemon  - Rsync daemon sources and destinations. A daemon is started on
#             127.0.0.1 for these tests. Skipped if it can't be started.
#   extra   - Tests that don't compare rsyncnow with rsync
#
# Environment variables:
#   RSYNCNOW            - Script to test (default: ../rsyncnow)
#   RSYNCNOW_TEST_PORT  - Port for rsync daemon (default: 8873)
#   RSYNCNOW_TEST_JOBS  - Number of tests to run in parallel (default: 8)
#
# Requirements: bash, GNU findutils and coreutils, rsync, ruby

set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export RSYNCNOW=${RSYNCNOW:-$HERE/../rsyncnow}
export PORT=${RSYNCNOW_TEST_PORT:-8873}
export USER=${USER:-$(id -un)}
JOBS=${RSYNCNOW_TEST_JOBS:-8}

# Options for rsyncnow without -e=ssh, which is needed for rsync daemon
DX="-- -a -- -lptgoD0 --files-from=-"

#######################################################################
# Tests which compare rsyncnow with rsync. Format of a line is:
#
#   name|group|working directory|SRC... DST|rsyncnow options|rsync options
#
# The following is replaced in SRC and DST:
#
#   {R} - Absolute path of the directory tree (see function setup)
#   {P} - Path of the directory tree inside of rsync daemon's module "mod"
#   {H} - Name of the temporary directory in $HOME (contains file1, sub/file2)
#   {U} - Current user

tests() { cat <<EOF
L01|local|.|a/ b||
L02|local|.|a b||
L03|local|.|./a/ b||
L04|local|.|./a b||
L05|local|.|a// b||
L06|local|.|a/. b||
L07|local|.|a/./ b||
L08|local|.|a/sub/../ b||
L09|local|.|a/sub/.. b||
L10|local|.|{R}/a/ {R}/b||
L11|local|.|{R}/a {R}/b||
L12|local|a|. ../b||
L13|local|a|./ ../b||
L14|local|a/sub|.. ../../b||
L15|local|a/sub|../ ../../b||
L16|local|b|../a/ .||
L17|local|a2|../a/ ../b||
L18|local|a2|../a ../b||
L19|local|.|a/sub/ b||
L20|local|.|a/sub b||
L21|local|.|{R}/a/./sub/ b||
L22|local|.|{R}/a/../a2 b||
L23|local|.|a/ a b||
L24|local|.|a a2 b||
L25|local|.|a/ a2/ b||
L26|local|.|a/ a2 b||
L27|local|.|'sp ace/' b||
L28|local|.|'sp ace' b||
L29|local|.|empty/ b||
L30|local|.|empty b||
L31|local|.|single/ nb||
L32|local|.|single nb||
L33|local|.|nope b||
F01|local|.|a/file1 b||
F02|local|.|a/file1 b/||
F03|local|.|a/file1 b/newname||
F04|local|.|a/file1 b/sub/||
F05|local|.|{R}/a/file1 {R}/b||
F06|local|.|a/sub/file2 b||
F07|local|.|a/file1 a2/other b||
F08|local|.|a/file1 a2 b||
F09|local|.|a/* b||
F10|local|.|a/file1 nb||
F11|local|.|a/file1 nb/||
F12|local|.|a/file1 a2/other||
F13|local|.|a/file1 stale||
F14|local|.|a/file1 stale/file1||
F15|local|.|a/sub/file2 a/file1 nb||
F16|local|.|a/file1 a2/other nb/||
F17|local|.|a/file1 a/sub nb||
F18|local|.|odd/ünï b/newname||
F19|local|.|odd/ünï a/file1 b||
F20|local|.|'odd/x -> y' b||
S01|local|.|lnk/ b||
S02|local|.|lnk b||
S03|local|.|lnk/l b||
S04|local|.|lnk/dl b||
S05|local|.|lnk/dl/ b||
S06|local|.|adir/ b||
S07|local|.|adir b||
N01|local|.|odd/ b||
N02|local|.|odd b||
D01|local|.|a/ nb||
D02|local|.|a/ nb/||
D03|local|.|a/ nb/x/y||
D04|local|.|a nb||
D05|local|.|a/ b/||
D06|local|.|a/ {R}/b/||
D07|local|.|a/ a2/other||
D08|local|.|a/ stale||
D09|local|.|a stale||
D10|local|.|a/ synced||
D11|local|.|a/ synced/||
O01|local|.|a/ b|-- -aniRe=ssh --size-only -- -lptgoD0e=ssh --files-from=- -W|
O02|local|.|a b|-- -aniRe=ssh --|
O03|local|.|a/ a2 b|-s 3 -b 1 -q 2|
O04|local|.|a/ nb|-b 1|
O05|local|.|a/sub a/file1 nb|-b 1 -s 2|
O06|local|.|a/ a2/ single/ lnk/ odd/ nb|-s 4 -b 1|
O07|local|.|a a2 single lnk nb/|-s 2|
O08|local|.|a/ a2/ single/ lnk/ odd/ b|-f 1|
O09|local|.|a/ a2/ single/ lnk/ odd/ nb|-f 2 -s 2|
O10|local|.|a a2 single nb|-f 1 -b 1|
O11|local|.|a/ a2 b|-f 5|
O12|local|.|a/file1 a2/other a/sub b|-f 2|
R01|ssh|.|localhost:{R}/a/ b||
R02|ssh|.|localhost:{R}/a b||
R03|ssh|.|localhost:{R}/a/file1 b||
R04|ssh|.|localhost:{R}/a/file1 b/newname||
R05|ssh|.|{U}@localhost:{R}/a/ b||
R06|ssh|.|localhost:{R}/a/ localhost:{R}/a2/ b||
R07|ssh|.|localhost:{R}/a localhost:{R}/a2/other b||
R08|ssh|.|localhost:{R}/a/ nb||
R09|ssh|.|localhost:{R}/single/ nb||
R10|ssh|.|'localhost:{R}/a/*' b||
R11|ssh|.|'localhost:{R}/sp ace/' b||
R12|ssh|.|localhost:{R}/a/sub b||
R13|ssh|.|localhost:{R}/a/sub/../ b||
R14|ssh|.|localhost:{R}/a/. b||
R15|ssh|.|localhost:{R}/lnk/ b||
R16|ssh|.|localhost:{R}/odd/ b||
R17|ssh|.|localhost:{H}/ b||
R18|ssh|.|localhost:{H} b||
R19|ssh|.|localhost:{H}/sub b||
R20|ssh|.|localhost:{H}/file1 b||
R21|ssh|.|'localhost:~/{H}/' b||
R22|ssh|.|'localhost:~/{H}' b||
R23|ssh|.|'localhost:~/{H}/file1' b/newname||
R24|ssh|.|localhost:{R}/a localhost:{R}/lnk/ b|-s 2 -b 2|
T01|ssh|.|a/ localhost:{R}/b||
T02|ssh|.|a localhost:{R}/b||
T03|ssh|.|a/ localhost:{R}/nb||
T04|ssh|.|single/ localhost:{R}/nb||
T05|ssh|.|lnk localhost:{R}/nb||
T06|ssh|.|odd/ localhost:{R}/b||
T07|ssh|.|a/file1 localhost:{R}/b||
T08|ssh|.|a/file1 localhost:{R}/b/newname||
T09|ssh|.|a/ a2 {U}@localhost:{R}/b||
T10|ssh|.|a/ localhost:{R}/nb|-b 1|
T11|ssh|.|a/ a2/ single/ lnk/ localhost:{R}/nb|-s 3 -b 1|
T12|ssh|.|a a2/ single localhost:{R}/nb|-f 1|
R25|ssh|.|localhost:{R}/a localhost:{R}/a2/ localhost:{R}/lnk b|-f 2|
G01|daemon|.|rsync://localhost:$PORT/mod/{P}/a/ b|$DX|
G02|daemon|.|rsync://localhost:$PORT/mod/{P}/a b|$DX|
G03|daemon|.|localhost::mod/{P}/a/ b|-- -a --port=$PORT -- -lptgoD0 --port=$PORT --files-from=-|--port=$PORT
G04|daemon|.|localhost::mod/{P}/a b|-- -a --port=$PORT -- -lptgoD0 --port=$PORT --files-from=-|--port=$PORT
G05|daemon|.|rsync://localhost:$PORT/mod/{P}/a/file1 b|$DX|
G06|daemon|.|rsync://localhost:$PORT/mod/{P}/a/file1 b/newname|$DX|
G07|daemon|.|rsync://localhost:$PORT/one b|$DX|
G08|daemon|.|rsync://localhost:$PORT/one/ b|$DX|
G09|daemon|.|rsync://localhost:$PORT/mod/{P}/lnk b|$DX|
G10|daemon|.|rsync://localhost:$PORT/mod/{P}/empty rsync://localhost:$PORT/mod/{P}/odd/ b|$DX|
G11|daemon|.|rsync://localhost:$PORT/mod/{P}/single/ nb|$DX|
G12|daemon|.|rsync://localhost:$PORT/mod/{P}/a/sub/../ b|$DX|
G13|daemon|.|a/ rsync://localhost:$PORT/mod/{P}/b|$DX|
G14|daemon|.|a rsync://localhost:$PORT/mod/{P}/b|$DX|
G15|daemon|.|single/ rsync://localhost:$PORT/mod/{P}/nb|$DX|
G16|daemon|.|rsync://localhost:$PORT/mod/{P}/a rsync://localhost:$PORT/mod/{P}/a2/ rsync://localhost:$PORT/mod/{P}/single b|-f 1 $DX|
EOF
}

#######################################################################
# Functions:

# Creates directory tree for one test in directory $1
setup() {
  local r=$1 f
  mkdir -p $r/a/sub $r/a2 $r/b $r/single "$r/sp ace/in ner" $r/empty $r/lnk/d $r/odd $r/stale $r/synced
  echo 1 > $r/a/file1; echo 22 > $r/a/sub/file2; echo xyz > $r/a2/other; echo only > $r/single/only
  echo s > "$r/sp ace/f s"; echo t > "$r/sp ace/in ner/g h"
  echo f > $r/lnk/f; echo g > $r/lnk/d/g
  ln -s f $r/lnk/l; ln -s d $r/lnk/dl; ln -s nowhere $r/lnk/dang
  ln -s a $r/adir
  for f in "x -> y" " lead" "trail " $'new\nline' "ünï" $'latin\351' 'back\slash' 'lit\#012x' "-dash" 'star*' 'q?' $'tab\tbed'; do
    echo o > "$r/odd/$f"
  done
  echo old-and-much-longer > $r/stale/file1; echo e > $r/stale/extra
  cp -a $r/a/. $r/synced/
}

# Prints the list of everything in directory $1 (with file sizes and checksums)
tree() {
  (cd "$1" && find . -mindepth 1 \
    \( -type f -printf 'f %p %s ' -exec sh -c 'md5sum < "$1" | cut -c1-8' _ {} \; \) -o \
    \( -type l -printf 'l %p -> %l\n' \) -o \
    -printf '%y %p\n' | LC_ALL=C sort)
}

# Runs test $1: once with rsyncnow (in $W/m/$1/now), once with rsync (in $W/m/$1/ref)
run_test() {
  local line n g cwd args nx rx mode root a
  line=$(tests | grep "^$1|"); IFS='|' read -r n g cwd args nx rx <<<"$line"
  mkdir -p $W/m/$n
  for mode in now ref; do
    root=$W/m/$n/$mode; setup $root
    a=${args//\{R\}/$root}; a=${a//\{P\}/$n/$mode}; a=${a//\{H\}/$HDN}; a=${a//\{U\}/$USER}
    cd $root/$cwd
    eval "set -- $a"
    if [ $mode = now ]; then
      eval "timeout 60 ruby $RSYNCNOW -t 0.5 \"\$@\" $nx" > $W/m/$n/$mode.log 2>&1
    else
      eval "timeout 60 rsync -a $rx \"\$@\"" > $W/m/$n/$mode.log 2>&1
    fi
    echo $? > $W/m/$n/$mode.rc
    tree $root > $W/m/$n/$mode.tree
  done
}

# Prints the result of test $1; returns 1 if it has failed
report_test() {
  local line n g cwd args nx rx nrc rrc ok=1
  line=$(tests | grep "^$1|"); IFS='|' read -r n g cwd args nx rx <<<"$line"
  nrc=$(cat $W/m/$n/now.rc); rrc=$(cat $W/m/$n/ref.rc)
  cmp -s $W/m/$n/now.tree $W/m/$n/ref.tree || ok=0
  [ $nrc = $rrc ] || ok=0
  # If rsync has succeeded, rsyncnow must not print any errors either
  [ $rrc != 0 ] || ! grep -qE 'rsync error|rsync:|[Ee]rror|warning' $W/m/$n/now.log || ok=0

  [ "$cwd" = . ] || args="$args (in $cwd)"
  if [ $ok = 1 ]; then
    echo "ok    $n  $args${nx:+  [$nx]}"
  else
    echo "FAIL  $n  $args${nx:+  [$nx]}  (exit status: rsyncnow $nrc, rsync $rrc)"
    sed "s#$W/m/$n/now#{R}#g" $W/m/$n/now.log | grep -v '^$' | awk '!s[$0]++' | head -5 | sed 's/^/        rsyncnow: /'
    diff $W/m/$n/ref.tree $W/m/$n/now.tree | grep '^[<>]' | head -10 |
      sed 's/^</        only with rsync:   /; s/^>/        only with rsyncnow:/'
    return 1
  fi
}

# Prints the result of an extra test: name, description, status (0 = ok)
report_extra() {
  if [ $3 = 0 ]; then echo "ok    $1  $2"; else echo "FAIL  $1  $2"; return 1; fi
}

# Prints what is left to sync from $1 to $2 (ignoring the attributes of the
# top-level directory, which rsyncnow doesn't sync)
left() {
  rsync -ani --delete "$1" "$2" | grep -v '^\.d\.\.t\.\.\.\.\.\. \./$'
}

#######################################################################
# Tests which don't compare rsyncnow with rsync. Each function returns 0
# if the test has passed.

# Creates directory src with 1200+ files, unless it already exists
big_tree() {
  local d f
  [ ! -d src ] || return 0
  for d in $(seq 1 30); do
    mkdir -p src/d$d/n1/n2
    for f in $(seq 1 40); do echo "$d-$f" > src/d$d/f$f; done
    echo x > src/d$d/n1/n2/deep; ln -s f1 src/d$d/lnk
    chmod 750 src/d$d/n1; chmod 600 src/d$d/f1
    touch -d '2020-01-02 03:04:05' src/d$d src/d$d/f2 src/d$d/n1/n2
  done
  mkdir src/emptydir
}

# More files than the queue can hold, so that finder gets paused (or exits
# before all of its output is read). Also checks that attributes are synced.
E01() {
  big_tree
  ruby $RSYNCNOW -t 0.2 -s 3 -b 7 -q 20 src/ dst1 > E01.log 2>&1 && [ ! -s E01.log ] && [ -z "$(left src/ dst1)" ]
}

# Nothing is given to syncers if everything is already synced
E02() {
  big_tree; rsync -a src/ dst2
  ruby $RSYNCNOW -v -t 0.2 src/ dst2 > E02.log 2>&1 && ! grep -q 'running syncer' E02.log
}

# Changed and new files are found and synced
E03() {
  big_tree; rsync -a src/ dst3
  echo changed > src/d7/f9; echo new > src/d9/newfile
  ruby $RSYNCNOW -t 0.2 src/ dst3 > E03.log 2>&1 && [ -z "$(left src/ dst3)" ]
}

# Same as E01, but directory itself is synced, into DST which doesn't exist
E04() {
  big_tree
  ruby $RSYNCNOW -t 0.2 -s 4 -b 7 -q 20 src dst4 > E04.log 2>&1 && [ ! -s E04.log ] && [ -z "$(rsync -ani --delete src dst4)" ]
}

# Verbose mode works, and shows what is being done
E05() {
  mkdir -p v; echo 1 > v/file
  ruby $RSYNCNOW -v -t 0.2 v/ dst5 > E05.log 2>&1 && grep -q 'Starting finder' E05.log && grep -q '^file$' E05.log
}

# Exit status is the one of rsync if finder fails...
E06() {
  ruby $RSYNCNOW -t 0.2 nope dst6 > E06.log 2>&1; [ $? = 23 ]
}

# ... and if syncer fails (DST can't be created)
E07() {
  mkdir -p v; echo 1 > v/file
  ruby $RSYNCNOW -t 0.2 v/ nope/x/y > E07.log 2>&1; [ $? = 11 ]
}

# Help and examples
E08() {
  ruby $RSYNCNOW -h | grep -q '^Usage: ' && ruby $RSYNCNOW -e | grep -q '^EXAMPLES:'
}

# Syncing is done as soon as finder is done, without waiting for the timeout
E09() {
  mkdir -p v; echo 1 > v/file
  SECONDS=0
  ruby $RSYNCNOW -t 10 v/ dst9 > E09.log 2>&1 && [ -f dst9/file ] && [ $SECONDS -lt 5 ]
}

# Runs rsyncnow with options $1 on three sources, using a wrapper for rsync
# which logs when each finder starts and ends. Prints that log in one line.
finders_log() {
  mkdir -p f1 f2 f3; echo 1 > f1/a; echo 2 > f2/b; echo 3 > f3/c
  cat > rsync-wrapper <<EOF
#!/bin/sh
case " \$* " in *" --dry-run "*)
  echo start >> $PWD/finders.log; rsync "\$@"; rc=\$?; sleep 0.5; echo end >> $PWD/finders.log; exit \$rc
esac
exec rsync "\$@"
EOF
  chmod +x rsync-wrapper; rm -f finders.log
  ruby $RSYNCNOW -t 0.2 -r ./rsync-wrapper $1 f1/ f2/ f3/ fdst > finders.out 2>&1 || return 1
  [ -f fdst/a ] && [ -f fdst/b ] && [ -f fdst/c ] || return 1
  echo $(cat finders.log)
}

# Number of finders running at the same time is limited with option -f
E10() {
  [ "$(finders_log '-f 1')" = "start end start end start end" ]
}

E11() {
  local log=$(finders_log '-f 2')
  [[ $log == "start start end "* ]] && [ "$(echo $log | tr ' ' '\n' | grep -c start)" = 3 ]
}

# By default there is one finder for every source
E12() {
  [ "$(finders_log '')" = "start start start end end end" ]
}

extras="E01:More_files_than_queue_size E02:Nothing_to_do_when_synced E03:Changes_are_synced
  E04:Directory_into_new_DST E05:Verbose_mode E06:Exit_status_of_finder E07:Exit_status_of_syncer
  E08:Help_and_examples E09:No_waiting_when_finder_is_done E10:One_finder_at_a_time
  E11:Two_finders_at_a_time E12:One_finder_per_source_by_default"

#######################################################################
# Run the tests:

# Internal: run a single test (used for running the tests in parallel)
if [ "${1:-}" = --run-test ]; then
  run_test "$2"
  exit
fi

keep=0; selected=
for arg; do
  case $arg in
    -k) keep=1 ;;
    -h|--help) sed -n '3,/^$/{s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
    -*) echo "Unknown option $arg" >&2; exit 2 ;;
    *) selected="$selected $arg" ;;
  esac
done

# Returns 0 if test $1 from group $2 should be run
wanted() {
  [ -z "$selected" ] || [[ " $selected " == *" $1 "* ]] || [[ " $selected " == *" $2 "* ]]
}

for cmd in ruby rsync timeout md5sum; do
  command -v $cmd > /dev/null || { echo "Command $cmd is required for running the tests" >&2; exit 2; }
done

export W=$(mktemp -d "${TMPDIR:-/tmp}/rsyncnow-test.XXXXXX") HDN=
HD=; DPID=
cleanup() {
  [ -z "$DPID" ] || { kill $DPID; wait $DPID; } 2> /dev/null
  [ -z "$HD" ] || rm -rf "${HD:?}"
  if [ $keep = 1 ]; then echo "Work directory: $W"; else rm -rf "${W:?}"; fi
}
trap cleanup EXIT
mkdir -p $W/m $W/one/sub $W/extra
echo 1 > $W/one/file1; echo 22 > $W/one/sub/file2

# Prints names of the tests from group $1 which should be run
wanted_from() {
  tests | while IFS='|' read -r n g rest; do
    [ $g = $1 ] && wanted $n $g && echo $n
  done
}

groups=" local extra "

# Group ssh needs ssh to localhost that works without asking anything
if [ -n "$(wanted_from ssh)" ]; then
  if ssh -o BatchMode=yes -o ConnectTimeout=5 localhost 'command -v rsync' > /dev/null 2>&1; then
    HD=$(mktemp -d "$HOME/rsyncnow-test.XXXXXX"); HDN=$(basename $HD)
    cp -a $W/one/. $HD/
    groups="$groups ssh "
  else
    echo "Skipping group ssh ('ssh -o BatchMode=yes localhost' doesn't work)"
  fi
fi

# Group daemon needs rsync daemon
if [ -n "$(wanted_from daemon)" ]; then
  cat > $W/rsyncd.conf <<EOF
port = $PORT
address = 127.0.0.1
use chroot = no
log file = $W/rsyncd.log
pid file = $W/rsyncd.pid
[mod]
path = $W/m
read only = no
[one]
path = $W/one
read only = yes
EOF
  rsync --daemon --no-detach --config=$W/rsyncd.conf & DPID=$!
  for i in 1 2 3 4 5 6 7 8 9 10; do
    rsync rsync://localhost:$PORT/ > /dev/null 2>&1 && { groups="$groups daemon "; break; }
    sleep 0.2
  done
  [[ $groups == *" daemon "* ]] || echo "Skipping group daemon (can't start rsync daemon on port $PORT)"
fi

# Names of the tests to run from group $1
names() {
  [[ $groups != *" $1 "* ]] || wanted_from $1
}

# Number of concurrent ssh tests is low because sshd limits the number of
# connections which aren't authenticated yet (option MaxStartups)
names local  | xargs -r -P $JOBS -n1 "$BASH" "$0" --run-test & p1=$!
names ssh    | xargs -r -P 4     -n1 "$BASH" "$0" --run-test & p2=$!
names daemon | xargs -r -P $JOBS -n1 "$BASH" "$0" --run-test & p3=$!
wait $p1 $p2 $p3

passed=0; failed=0
for n in $(names local; names ssh; names daemon); do
  if report_test $n; then passed=$((passed+1)); else failed=$((failed+1)); fi
done

cd $W/extra
for extra in $extras; do
  n=${extra%%:*}; desc=${extra#*:}
  wanted $n extra || continue
  $n; if report_extra $n "${desc//_/ }" $?; then passed=$((passed+1)); else failed=$((failed+1)); fi
done

echo
echo "Passed: $passed, failed: $failed"
[ $failed = 0 ] && [ $passed != 0 ]
