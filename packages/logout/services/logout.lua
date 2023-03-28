_ENV()

local args = get_args()
args.meth = 'logout'
service.response = route('auth.auth', args)