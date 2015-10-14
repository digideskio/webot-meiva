middlewares= {}

middlewares.watch= (app, options)->
	options= options or {}
	pass= (req, res, next)-> next()
	path= options.path or '/'
	verify= options.verify or pass
	prop= options.prop or 'webot_info'

	parser= options.parser or (req, res, next)->
		req[prop]= req.body
		next()

	send= options.send or (req, res)-> res.json(res[prop])

	self= @
	app.get path, verify
	app.post path, verify, parser, (req, res, next)->
		self.reply req[prop], (err, info)->
			res[prop]= info
			next()
	, send

module.exports= exports= middlewares