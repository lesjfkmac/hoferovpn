# hoferovpn

This tool was devellopped to help me to reinstall my vpn setup on a synology ds107 and a wdmycloud nas devices.

Each firmware upgrade erased the setup, so I went to decide to automate the whole OpenVpn client/server process.

It was also an exercise to learn bash and debian programming. So be indulgent for the code style and bugs...

All this relies on:
  openssl
  openvpn linux/ios/android
  iptables
  easyrsa
 
 Code is devellopped like zn interpreter and a set of functions that may be executed as a whole or one by one in a logical way.
 Most of the coding was inspired from the easyrsa source (thanks for this team) 
 
 The design is the following:
  A set of build functions to download easyrsa tools and compile keys, certificates, ovpn setup files for servers and clients.
  A two mode installation way. 
    Building a bootstrap file that merge setup files and an auto-extract script can be uploaded and executed to install evevry thing on a server
    Direct install from the setup files.
    
    there are many help supposed to be update to date.... and a debug mode --x to trace the code/functions as some may have bugs...
    enjoy !
