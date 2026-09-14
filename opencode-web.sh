#!/bin/bash

docker exec -it pharo-ab-opencode01 bash -lc 'opencode web --hostname 0.0.0.0 --port 4096'
