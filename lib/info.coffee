utils= require './utils'
Rule= require './rule'

Info= (props)->
	if props instanceof Info then return props
	unless @ instanceof Info then return new Info(props)
	@session= null
	@webot= null
	@type= undefined
	utils.extend @, props

Object.defineProperty Info.prototype, 'sessionId', { get: ()-> @session and @session.id or @uid }

# Check request info type
Info::is= (type)-> return @type is type

# @method wait 标记消息为需要等待操作，需要 session 支持
Info::wait= (rule)->
	self= @
	if rule
		if rule instanceof Rule then rule= rule.name
		if 'string' isnt typeof rule then throw new Error 'Invalid wait rule name'
		self.session.waiter= rule
	return self	

Info::rewait= ()->
	sess= @session
	c= sess.rewait_count or 0
	sess.rewait_count= c+ 1
	@wait sess.last_waited

Info::resolve= ()->
	sess= @session
	delete sess.rewait_count
	delete sess.waiter
	delete sess.last_waited

module.exports= exports= Info
