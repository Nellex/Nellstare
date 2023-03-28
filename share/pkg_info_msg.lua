local pkg_info_msg = [=[
--------------------------------------
 Nellstare Framework package tool
            Version: %s
          Senin Stanislav
--------------------------------------

pkg [options] [key] [project_name] package_name [target]

Options:
install - install package
uninstall - uninstall package
reinstall - reinstall package
check - check package
checkinstall - check package on "installed" state
lock - lock package in project
unlock - unlock package in project
build - build package
update - update file from dir to package

Keys:
-p - use project name
-a - set all dependencies. Works within uninstall
-t - run all package scripts in testing mode from package source directory
-i - show package info

Examples:
pkg install hub - install package 'hub' in all projects
pkg install -p public_proj hub - install package 'hub' in project 'public_proj'
pkg lock -p public_proj hub - lock package 'hub' in project 'public_proj'
pkg unlock -p public_proj hub - unlock package 'hub' in project 'public_proj'
pkg uninstall hub - removes all package data from current instance
pkg uninstall -a hub - removes all package data from current instance and force
removes all dependencies
pkg build hub - build package 'hub' from sources
pkg update hub components/js/hub.js
pkg update hub services/hub.lua
pkg update reinstall -p public_proj hub services/hub.lua
pkg update reinstall unlock hub components/js/hub.js
pkg update reinstall unlock -p public_proj hub components/js/hub.js
pkg reinstall hub - reinstall 'hub' package in all projects
pkg build reinstall -p public_proj hub
]=]

return pkg_info_msg
