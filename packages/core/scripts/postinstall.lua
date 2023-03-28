local core_package_lock_cmd = string.format(pkg_cmd, NEF_PATH, 'lock core &')
core_package_lock_cmd = 'sleep 5 && ' .. core_package_lock_cmd

os.execute(core_package_lock_cmd)

return true
