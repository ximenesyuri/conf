#!/usr/bin/env bash

killall -q polybar

# Wait until the processes have been shut down
while pgrep -x polybar >/dev/null; do sleep 1; done

# Launch Polybar on each connected monitor
for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
  MONITOR=$m polybar i3 -c ~/conf/i3/polybar.ini &
done
