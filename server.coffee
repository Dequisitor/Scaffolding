express = require 'express'
app = express()
morgan = require 'morgan'
dcollector = require './DCollector/dcollector'
dprocessor = require './DCollector/dprocessor'

app.use morgan '[:date[clf]] :remote-addr :method :url :status :response-time ms :user-agent'
app.use '/dcollector', dcollector
app.use '/dprocessor', dprocessor

app.listen 3000, ->
	console.log 'server started ...'
