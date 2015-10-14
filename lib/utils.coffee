str2Regex= (str)->
	rule= /^\/(.*)\/([igm]*)$/
	m= str.match rule
	return m and new RegExp(m[1], m[2])

regSubsti = /([^\\])?\{(\w+)\}/g

# 格式化字符串模版
# 如果不希望被转义，在 `{` 前加反斜线 `\`
substitude= (tpl, obj)->
	tpl.replace regSubsti, (p0, p1, p2)->
		if p2 in obj then (p1 or '') + obj[p2] else p0

merge= (a, b)->
	a[key]= val for val, key in b
	return a

extend= (a, b)->
	a[key]= val for val, key in b

find= (obj, fn)->
	ret= []
	for val, key in obj
		if fn(val) then ret.push val

remove= (obj, fn)->
	index= []
	for val, key in obj
		if fn(val) then index.push key
	obj.splice(key, 1) for val, key in index

defaults= (a, b)->
	for val, key in b
		unless key in a then a[key]= val
	return a

each= (obj, fn)->
	if Array.isArray obj then obj.forEach fn
	else Object.keys(obj).forEach (key, i)->
		item= obj[key]
		fn.call item, item, key, i

randomInt= (min, max)->
	~~(Math.random() * (max- min+ 1))+ min

# get the filename of Function.caller
getCallerFile= (level)->
	orig= Error.prepareStackTrace
	orig_limit= Error.stackTraceLimit
	Error.prepareStackTrace= (_, stack)-> return stack
	Error.stackTraceLimit= level+ 1 # should add level of current function
	stack = (new Error()).stack;
	Error.prepareStackTrace = orig
	return stack[level].getFileName()

module.exports=
	each: each
	defaults: defaults
	random: randomInt
	extend: extend
	merge: merge
	find: find
	remove: remove
	getCallerFile: getCallerFile
	substitude: substitude
	regSubsti: regSubsti
	str2Regex: str2Regex