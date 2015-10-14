PATH= require 'path'
util= require 'util'
EventEmitter= require 'events'
					  .EventEmitter
utils= require '/utils'					  
Info= require './info'
Rule= require './rule'

# class Webot
Webot= (config)->
	config= config or {}
	if not @ instanceof Webot or @ is module.exports then return new Webot config

	@config= utils.defaults config, Webot.defaultConfig
	@befores= []
	@afters= []
	@routes= []
	@waits= {}
	@domain_rules= {}

util.inherits Webot, EventEmitter

# Parse rule definations
Webot::_rule= (arg1, arg2, arg3)->
	self= @
	args= arguments
	rule= {}
	switch args.length
		when 0 then throw new Error 'Invalid rule'
		when 1
			if typeof arg1 is 'function'
				rule.handler= arg1
				rule.pattern= null
			else rule= arg1
		when 2
			if typeof arg1 is 'string' and typeof arg2 is 'object' and arg2.handler?
				rule= arg2
				rule.name= arg1
		else
			rule.pattern= arg1
			rule.handler= arg2
			rule.replies= arg3
	return Rule.convert rule

# Add a reply rule
Webot::set= ()->
	rule= @_rule.apply @, arguments
	@routes= @routes.concat rule
	return @

# Preprocess on a request message
Webot::beforeReply= Webot::use= ()->
	rule= @_rule.apply @, arguments
	rule.forEach (item)->
		item._is_before_rule= true
	@befores= @befores.concat rule
	return @

# Add domain specified rules
Webot::domain= (domain)->
	self= @
	args= Array.prototype.slice.call arguments, 1
	rules= self._rule.apply self, args

	unless domain in self.domain_rules then self.domain_rules[domain]= []
	self.domain_rules[domain]= self.domain_rules[domain].concat rules
	return @

# Post-process of a reply message
Webot::afterReply= ()->
	@afters= @afters.concat @_rule.apply @, arguments
	return @

# Get a wait rule
Webot::getWaitRule= (rule_name)->
	rule= @waits[rule_name] or @get rule_name
	if not rule and rule_name.indexOf '_reply_' is 0
		rname= rule_name.replace '_reply_', '', 1
		rule= @get rname
		if rule.replies? then rule= @waits[rule_name]= Rule.convert rule.replies, rule
	return 	rule

# set or get a wait rule
# wait rule must be named
Webot::waitRule= (rule_name, rule)->
	if arguments.length is 1 then return @getWaitRule rule_name

	if rule_name in @waits then throw new Error 'Wait rule name conflict'
	if typeof rule isnt 'object'
		rule= { handler: rule }

	rule.name= rule_name
	@waits[rule_name]= @_rule rule
	return @


# Get a route or wait rule
Webot::get= (name)->
	return @gets(name)[0] or @waits[name]
Webot::gets= (name, from)->
	from= from or @routes
	return if name? then utils.find(from, (rule)-> return rule.name is name) else from
Webot::update= ()->
	newRule= @_rule.apply @, arguments
	utils.each @routes, (rule)->
		utils.each newRule, (r)->
			if rule.name is r.name then utils.merge rule, r
	return @
Webot::delete= (name)->
	utils.remove @routes, (rule)-> return rule.name is name
# @param  {String/Array} filepath, could be a list of files.
Webot::dialog= (args)->
	self= @
	unless Array.isArray args then args= Array::slice.call arguments
	dir= getCallerDir()
	args.forEach (p)->
		if 'string' is typeof p
			p= PATH.resolve dir, p
			p= require p
		utils.each p, (item, key)->
			rule= null
			if 'string' is typeof item or Array.isArray item
				if 'number' is typeof key and item.length is 2
					key= item[0]
					item= item[1]
				rule=
					name: 'dialog_'+ key
					pattern: key
					handler: item
			else
				rule= item
				rule.name= rule.name or 'dialog_'+ key
				rule.pattern= rule.pattern or key
			self.set rule
	return @

Webot::loads= (mods)->
	unless Array.isArray mods then mods= Array::slice.call arguments
	self= @
	dir= getCallerDir()

	mods.forEach (name)->
		mod= require PATH.resolve dir, name
		if 'function' is typeof mod then mod self
		else
			mod.name= mod.name or name
			self.set mod
	return self

# Empty all rules
Webot::reset= ()->
	@befores= []
	@afters= []
	@routes= []
	@waits= {}
	@domain_rules= {}
	return @

# Reply to a message
Webot::reply= (data, cb)->
	self= @
	info= Info data
	info.webot= self

	if not self.config.keepBlank and info.text then info.text= info.text.trim()

	# 要执行的rule列表
	ruleList= self.routes

	# 如果用户有waiting rule待执行
	waiter= info.session and info.session.waiter
	if waiter?
		delete info.session.waiter
		# 但把它存放在另外的地方
		info.session.last_waited= waiter
		waiter= self.waitRule waiter
		ruleList= [].concat waiter
					.concat self.routes
		info.rewaitCount= info.session.rewait_count or 0
	else if info.session? then delete info.session.rewait_count

	ruleList= @befores.concat ruleList
	self._reply ruleList, info, cb
	return self

# Reply a message according to specified rule list
Webot::_reply= (ruleList, info, cb)->
	self= @
	breakOnError= self.config.breakOnError
	isAfter= false
	end= (err, reply)->
		unless reply? or err then err= 500
		if err?
			info.err= err
			reply= reply or self.code2reply err
		if Array.isArray reply and 'string' is typeof reply[0] then reply= reply[utils.random(0, reply.length- 1)]
		info.reply= reply or info.reply or ''

		# Run after reply rules
		unless isAfter
			ruleList= self.afters
			isAfter= true
			tick(0)
			return
		cb err, info

	tick= (i, domain)->
		rule= ruleList[i]
		unless rule? then return end (if isAfter then null else 404), info.reply
		info.ruleIndex= i
		info.currentRule= rule
		if rule._is_before_rule and rule.domain isnt domain then tick(i+ 1, domain)
		unless rule.test info then return tick(i+ 1, domain)
		if rule.domain? and not domain
			_domain= rule.domain
			# insert domain befores to the begining
			ruleList= self.domain_rules[_domain].concat(ruleList.slice i)
			# run from start again
			return tick 0, _domain
		if isAfter
			rule.exec info, (err, result)->
				if err and breakOnError then end err, result
				tick(i+ 1)
			return

		rule.exec info, (err, result)->
			if err and breakOnError then return end err, result
			if result or info.ended
				# 存在要求回复的规则
				if rule.replies then info.wait '_reply_'+ rule.name
				return end(err, result)
			tick(i+ 1, domain)
	tick(0)

Webot.defaultConfig=
	keepBlank: true
	breakOnError: true

Webot::codeReplies=
	'204': 'OK, got that.'
	'403': 'You have no permission to do this.'
	'404': '抱歉，你输入的命令未被系统录入或者命令有误。尝试其他命令，例如【ls】'
	'500': 'Something is broken...'

# 根据status code 获取友好提示消息
Webot::code2reply= (code)->
	code= String code
	return if code in @codeReplies then @codeReplies[code] else code

# backward compatibility
Webot.exec= Rule.exec

# Legacy API compatibility
Webot::exec= (info, rule, cb)->
	return Rule rule
				.exec info, cb

# export express middlewares
utils.extend Webot.prototype, require './lib/middleware'

# get the name of a rule / rules
getRuleName= (rule)->
	unless rule then return '[NULL RULE]'
	return if Array.isArray rule then rule[0].name+ (if rule.length > 1 then '..' else '') else rule.name

# get dirname of caller function
getCallerDir= ()->
	file= utils.getCallerFile 3
	return PATH.dirname file

# Export a default webot
module.exports= new Webot()
module.exports.Rule= Rule
module.exports.Info= Info
module.exports.Webot = module.exports.WeBot = Webot