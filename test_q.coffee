Q = require 'q'
request = require 'request'

urls = [
  'google.com'
  'twitter.com'
  'facebook.com'
  ]

queue = []
context = []

fetchUrl = (url, context) ->
  #console.log "fetchUrl context #{JSON.stringify context}"
  deferred = Q.defer()
  request {
    url: 'http://' + url
  },
  (err, res, body) ->
    console.log "fetchurl callback context #{JSON.stringify context}"
    if err 
      context.push 'no'
      deferred.reject err
    else
      console.log "fetchurl got response"
      context.push 'yes'
      deferred.resolve {
        headers: res.headers
      }

  return deferred.promise

context.push '0'
console.log "before foreach context #{JSON.stringify context}"
urls.forEach (url) ->
  queue.push fetchUrl url, context

console.log "start 1st #{queue}"

Q.all queue
  .then (ful1) ->
    #console.log "1st fulfilled #{JSON.stringify ful1, null, 2}"
    queue2 = []
    context2 = []
    context3 = []
    context.push context2
    context.push context3
    urls = ['spirent.com', 'google.com']
    urls.forEach (url) ->
      queue2.push fetchUrl url, context2
    urls.forEach (url) ->
      queue2.push fetchUrl url, context3
    console.log "start 2nd #{queue2}"
    Q.all queue2
      .then (ful2) ->
        context.push '3'
        console.log "2nd fulfilled #{JSON.stringify ful2, null, 2}"
        console.log "done context #{JSON.stringify context}"
  .then (ful) ->
    # queue = []
    # Q.all queue
    console.log "finally 1 #{JSON.stringify ful}"
    return 'hello!!!'
    
  .then (ful) ->
    console.log "finally #{JSON.stringify ful}"

#console.log "done context #{JSON.stringify context}"