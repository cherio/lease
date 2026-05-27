#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Yuri Cherio

this_dir="$(dirname "$(realpath "$0")")"
cd "$this_dir" || exit 1

./lease-test-auto1.pl --test=16x2+3 -r test -c 2 -i 3 -w 16 -k 4 -v -v --release 2>&1 # | tee /tmp/lease-test-auto1.log
