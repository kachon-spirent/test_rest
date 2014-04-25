request = require 'request'
qs = require 'querystring'
Q = require 'q'

class RestApi
  constructor: (@host,
                @userid='restapi', 
                @sessionname='restapi',
                @sessionid="#{@userid} - #{@sessionname}")->
    

  get_url: ->
    "http://" + @host

  get_session_api: ->
    "#{@get_url()}/stcapi/v1/sessions/"

  get_obj_api: ->
    "#{@get_url()}/stcapi/v1/objects/"

  get_session_header: ->
    {'X-STC-API-Session': "#{@sessionid}"}

  handle_response: (error, response, body) ->
    if error
      console.log "got error #{error}"
      return {status: false}
    else if response.statusCode >= 400
      console.log "got error status code #{response.statusCode} #{body}"
      return {status: false}
    else
      console.log "got response #{body}"
      body = '{}' if not body    
      return {
        status: true
        data: JSON.parse body
      }

  create_session: ->
    api = @get_session_api()
    form = 
      userid: @userid
      sessionname: @sessionname
    console.log "start create_session #{api}"
    request.post {
      url: api
      form: form
      },
      (error, response, body) =>
        res = @handle_response error, response, body
        if not res.status
          console.log "Failed to created session"
        else
          @sessionid = res.data.session_id
          console.log "Created session: #{res.data} #{@sessionid}"

  delete_session: ->
    api = "#{@get_session_api()}#{@sessionid}/"
    console.log "start delete_session #{api}"
    request.del {
      url: api
    },
    (error, response, body) =>
        @handle_response error, response, body
        console.log "Finished delete_session #{api}"

  get_all_session: ->
    api = @get_session_api()
    console.log "start get_all_session #{api}"
    request.get {
      url: api
      },
      (error, response, body) ->
        if error
          console.log "got error #{error}"
        else if response.statusCode isnt 200 
          console.log "got error #{body}"
        else
          console.log "got response #{body}"
    console.log 'end get_all_session'

  get_obj: (obj, callback) =>
    console.log 'start get_obj'
    api = "#{@get_obj_api()}#{obj}/"
    options = {
      url: api
      headers: @get_session_header()
    }
    request.get options,
      (error, response, body) =>
        res = @handle_response error, response, body
        console.log "Finished get_obj_api #{api}"
        callback res

  get_obj_promise: (obj) ->
    deferred = Q.defer()
    request {
      url: 'http://' + 'twitter.com'
    }, (err, res, body) ->
      if err 
        deferred.reject err
      else
        deferred.resolve {
          headers: res.headers
        }

    return deferred.promise

  # get_obj_promise: (obj) ->
  #   deferred = Q.defer()
  #   #api = "#{@get_obj_api()}#{obj}/"
  #   api = 'http://twitter.com'
  #   options = {
  #     url: api
  #     #headers: @get_session_header()
  #   }
  #   request.get options,
  #     (error, response, body) =>
  #       res = @handle_response error response, body
  #       if not res.status 
  #         deferred.reject res
  #       else
  #         deferred.resolve res

  #   return deferred.promise

  # send_data: ->
  #   console.log 'start send_data'
  #   request.get {
  #     url: 'http://api.duckduckgo.com/',
  #     qs: { q: 'DuckDuckGo', format: 'json' }
  #     },
  #     (error, response, body) ->
  #       console.log "got response #{error} #{body}"
  #   console.log 'end send_data'



module.exports = RestApi