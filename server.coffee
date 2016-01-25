express = require 'express'
app = express()
morgan = require 'morgan'
fs = require 'fs'
chalk = require 'chalk'

app.use morgan '[:date[clf]] :remote-addr :method :url :status :response-time ms'

console.log 'checking subdirectories ... '
modules = []
dirs = fs.readdirSync './'
for dir in dirs when fs.statSync(dir).isDirectory()
	files = fs.readdirSync './'+dir
	for file in files when file.match(/\w+\.coffee$/i)
		console.log 'found module /'+dir+'/'+file
		module_name = file.replace /\.coffee/, ''
		modules.push {name: module_name, module: require './'+dir+'/'+module_name }
		console.log 'module ' + module_name + ' loaded (#' + modules.length + ')'

console.log ''
for module in modules
	app.use '/'+module.name, module.module
	console.log(chalk.yellow 'registered module ' + module.name + ' under /' + module.name)

app.listen 3000, ->
	console.log ''
	console.log(chalk.green 'server started ...')
