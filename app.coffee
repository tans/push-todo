require("dotenv").config()
koa = require "koa"
Router = require "koa-router"
render = require "koa-ejs"
serve = require "koa-static"
fs = require "fs/promises"
path = require "path"
axios = require "axios"
koaBody = require "koa-body"
Datastore = require "nedb-promises"
schedule = require "node-schedule"
_ = require "lodash"
sleep = ->
	new Promise (resolve) ->
		setTimeout resolve, _.random(1.2, 3.2) * 1000

schedule.scheduleJob "0 0 * * *", ->
	files = await fs.readdir "./txt"
	for filename in files
		try
			rs = await fs.readFile "./txt/" + filename
			content = rs.toString()
			if content
				content = encodeURIComponent content
				await axios.get(
					"https://push.bot.qw360.cn/send/#{filename.replace(
						".txt"
						""
					)}?msg=#{content}"
				)
				await sleep()
		catch e
			console.log e

console.log process.env.USERDB or "./user.db"
UserDB = Datastore.create process.env.USERDB or "./user.db"
route = new Router()
app = new koa()

render app,
	root: path.join __dirname, "views"
	viewExt: "html"
	layout: "layout"
	map: html: "ejs"
	cache: false
app.use koaBody multipart: true
app.use serve path.join __dirname, "public"

checkToken = (ctx, next) ->
	ctx.state.token =
		ctx.request.params.token or
		ctx.request.query.token or
		ctx.cookies.get "token"

	ctx.state.msg = "token 不存在"
	unless ctx.state.token
		return await ctx.render "index"
	ctx.state.user = await UserDB.findOne token: ctx.state.token

	unless ctx.state.user
		return await ctx.render "index"

	ctx.cookies.set "token", ctx.state.token
	await next()

route.get "/", (ctx) ->
	await ctx.render "index"

route.get "/:token", checkToken, (ctx) ->
	token = ctx.params.token
	filepath = "./txt/#{token}.txt"
	try
		stat = await fs.stat filepath
	catch e
		await fs.writeFile filepath, ""

	rs = await fs.readFile filepath
	content = rs.toString()

	await ctx.render "todo", content: content

route.post "/saveTodo", checkToken, (ctx) ->
	{ content } = ctx.request.body
	filepath = "./txt/#{ctx.state.token}.txt"
	await fs.writeFile filepath, content
	ctx.body = status: true

app.use route.routes()

app.on "error", console.log

app.listen process.env.PORT || 3002, (err) ->
	console.log err if err
	console.log "listen port " + (process.env.PORT || 3002)
