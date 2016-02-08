# Scaffolding
This is a main server for my raspberry pi. When it starts it check for subdirectories, if it finds any, the it checks for coffee (pm before that) files, and tries to include them. Ideally they are files with express routers. So the scaffolding server registeres these sub-servers under his domain, and they are ready to be used. This way I only have to create the routers and not the whole application/server itself, and all the servers can be run on one port.

Future plans include auto deployment with github hooks (if the server detects a change/push, then stops the sub-server and checks out the code, then restarts it), and runtime checks for new sub-servers (with reaccurring checkd or on-demand calls).

Added bash script which can install the server as a service on linux systems. Creates detailed logs in /var/logs/scaffolding.log.

## Issues
Hadn't had time yet to solve the fixed directory problem in bash script file.
