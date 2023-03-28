do
    local package_dir = lib_pkg:get_pkg_path(pkg.package_config.name)
    local src_dir = './js/src'
    local out_dir = './js'
    local build_cmd = 'babel --plugins /usr/local/lib/node_modules/@babel/plugin-transform-react-jsx %s --out-file %s'

    local src_files = {
        'themeSwitcherState.js',
        'api.js',
        'themeSwitcherButton.js',
        'launcher.js'
    }

    for i=1, #src_files do
        local s = string.format('%s/%s/%s', package_dir, src_dir, src_files[i])
        local o = string.format('%s/%s/%s', package_dir, out_dir, src_files[i])
        local cmd = string.format(build_cmd, s, o)
        os.execute(cmd)
    end
end