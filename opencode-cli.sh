#!/bin/bash

docker exec -it pharo-ab-opencode01 bash -lc 'cd /root/smalltalk-interop/agentic-browser && opencode "$@"' -- "$@"
