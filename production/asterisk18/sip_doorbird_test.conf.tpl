; DoorBird/G1 test profile for isolated Asterisk 18 instance

[general]
udpbindaddr=0.0.0.0:__AST_SIP_PORT__
tcpenable=no
allowguest=no
videosupport=yes
progressinband=yes
prematuremedia=yes
directmedia=no
disallow=all
allow=ulaw
allow=h264

[doorbird]
type=friend
host=dynamic
port=__DOORBIRD_SIP_PORT__
defaultuser=doorbird
secret=doorbird
nat=force_rport,comedia
context=doorbird-in
insecure=port,invite
disallow=all
allow=ulaw
allow=h264
directmedia=no

[g1_23]
type=peer
host=__G1_23_IP__
port=__G1_SIP_PORT__
insecure=port,invite
qualify=yes
disallow=all
allow=ulaw
allow=h264
directmedia=no

[g1_53]
type=peer
host=__G1_53_IP__
port=__G1_SIP_PORT__
insecure=port,invite
qualify=yes
disallow=all
allow=ulaw
allow=h264
directmedia=no

[kproxy]
type=peer
host=__PI_IP__
port=__KPROXY_PORT__
insecure=port,invite
context=doorbird-in
disallow=all
allow=ulaw
allow=h264
directmedia=no

[preview_local]
type=peer
host=__PI_IP__
insecure=port,invite
context=doorbird-in
disallow=all
allow=ulaw
allow=h264
directmedia=no
