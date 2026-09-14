#!/bin/bash

docker exec -it sis-pharo01 bash -lc 'cd /root/smalltalk-interop/agentic-browser && opencode "$@"' -- "$@"
