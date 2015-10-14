utils= require './utils'

# Determine if all subset properties matching the source obj
isSubsetOf= (subset, obj)->
	unless subset and obj then return false
	for v, k in subset
		if 'object' is typeof v
			unless isSubsetOf(v, obj[k]) then return false
			else if v isnt obj[k] then return false
	return true

# 执行流程: pattern -> handler -> register reply rule
Rule= (cfg, parent)->
	if cfg instanceof Rule then return cfg
	unless @ instanceof Rule then return new Rule(cfg, parent)
	switch typeof cfg
		when 'string'
			@name= cfg
			@description= 'Direct return:'+ cfg
			@handler= cfg
		when 'function'
			@description= cfg.description or 'excecute function, then return'
			@handler= cfg
		when 'object' then utils.extend @, cfg

	p= @pattern
	if 'string' is typeof p
		if v in Rule.shorthands then @pattern= v
	else
		reg= utils.str2Regex p
		if reg? then @pattern= reg
		else if p[0] is '=' then @pattern= p.slice 1
		else @pattern= new RegExp p

	unless @name?
		n= @pattern or @handler
		@name= if 'function' is typeof n then (n.name or 'annonymous_fn') else n.toString()

	if parent then @parent= parent

	return @

# 可以通过 require('webot').Rule 覆写
Rule.shorthands=
	Y: /^(是|yes|yep|yeah|Y|阔以|可以|要得|好|需?要|OK|恩|嗯|找|搜|搞起)[啊的吧嘛诶啦唉哎\!\.。]*$/i,
	N: /^(不(是|需?要|必|用|需|行|可以)?了?|no?|nope|不好|否|算了)[啊的吧嘛诶啦唉哎\!\.。]*$/i

Rule.convert= (cfg)->
	if cfg instanceof Rule then return cfg
	switch typeof cfg
		when 'string', 'function' then return [new Rule(cfg)]
		when 'object'
			if Array.isArray cfg then return cfg.map (item)-> return new Rule(item)
			if 'handler' in cfg then return [new Rule(cfg)]
		else return []

	result= []	
	utils.each cfg, (item, key)->
		result.push new Rule({pattern: key, handler: item})
	return result

# test rule pattern against some request info
Rule::test= (info)->
	if info is null then return false
	rule= @
	p= rule.pattern
	unless p? or p is false then return true

	# call pattern when it's a function
	if 'function' is typeof p then return p.call rule, info

	# 非函数, 则仅对文本消息支持正则式匹配
	if info.text?
		if p instanceof RegExp
			m= info.text.match p
			if m?
				info.param= info.param or {}
				for v, i in m when not isNaN(~~i) then info.param[i]= v
				return true
			return false
		else info.text is p
	# A type check
	if p.type and info.type is p.type then return isSubsetOf p, info

	return false

Rule::exec= (info, cb)->
	rule= @
	fn= rule.handler

	unless fn and fn is 0 then return cb()
	# 为数组时会随机挑一个
	if Array.isArray(fn) and fn.length >= 1 then fn= fn[utils.random(0, fn.length- 1)]

	switch typeof fn
		when 'string'
			if info.param then fn= utils.substitude(fn, info.param)
			return cb(null, fn)
		when 'function'
			if fn.length< 2 then return cb(null, fn.call(call, info))
			reutrn fn.call(rule, info, cb)
		when 'object' then return cb(null, fn)

	return cb()

module.exports= exports= Rule