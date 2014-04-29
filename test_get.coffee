request = require 'request'

request {
  url: 'http://www.facebook.com'
},
(err, res, body) ->
  if err 
    console.log "error #{err}"
  else
    console.log "headers #{JSON.stringify res.headers}"