#
# Copyright 2020 Tom van den Berg (TNO, The Netherlands).
# SPDX-License-Identifier: Apache-2.0
#

FROM busybox

ENV LRC_SCRIPTS_HOME=/scripts

ADD scripts ${LRC_SCRIPTS_HOME}/
RUN chmod +x ${LRC_SCRIPTS_HOME}/launch.sh
