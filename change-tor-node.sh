#!/usr/bin/env sh
# Ändert das Tor-Routing (wie im Tor-Browser ein neuer Circuit)
# https://debianforum.de/forum/viewtopic.php?t=179475#p1256916
#echo -e '\''AUTHENTICATE "a"\nsignal NEWNYM\nQUIT'\' | nc 127.0.0.1 9050
cat <<! | ncat 127.0.0.1 9050
AUTHENTICATE "a"
signal NEWNYM
QUIT
!

