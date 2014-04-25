Q = require 'q'
request = require 'request'

urls = [
  'google.com'
  'twitter.com'
  'facebook.com'
  ]
queue = []

fetchUrl = (url) ->
  deferred = Q.defer()
  request {
    url: 'http://' + url
  },
  (err, res, body) ->
    if err 
      deferred.reject err
    else
      deferred.resolve {
        headers: res.headers
      }

  return deferred.promise

urls.forEach (url) ->
  queue.push fetchUrl url

console.log "start 1st #{queue}"
Q.all queue
  .then (ful) ->
    console.log "1st fulfilled #{JSON.stringify ful, null, 2}"
    queue2 = []
    urls = ['spirent.com']
    urls.forEach (url) ->
      queue2.push fetchUrl url
    console.log "start 2nd #{queue2}"
    Q.all queue2
      .then (ful) ->
        console.log "2nd fulfilled #{JSON.stringify ful, null, 2}"

