request = require 'request'
qs = require 'querystring'
Q = require 'q'

class BllApi
  constructor: (@host,
                @userid='bllapi', 
                @sessionname='bllapi',
                @sessionid="#{@userid} - #{@sessionname}")->
    
  get_url: ->
    "http://" + @host

  get_session_api: ->
    "#{@get_url()}/stcapi/v1/sessions/"

  get_obj_api: ->
    "#{@get_url()}/stcapi/v1/objects/"

  get_connection_api: ->
    "#{@get_url()}/stcapi/v1/connections/"

  get_session_header: ->
    {'X-STC-API-Session': "#{@sessionid}"}

  handle_response: (error, response, body) ->
    if error
      console.log "got error #{error}"
      return {status: 'failed'}
    else if response.statusCode >= 400
      console.log "got error status code #{response.statusCode} #{body}"
      return {status: 'failed'}
    else
      console.log "got response #{body}"
      body = '{}' if not body    
      return {
        status: 'ok'
        data: JSON.parse body
      }

  handle_response_with_result: (error, response, body, result) ->
    if error
      #console.log "got error #{error}"
      result.status = 'failed'
      result.data = error
      result
    else if response.statusCode >= 400
      #console.log "got error status code #{response.statusCode} #{body}"
      result.status = 'failed'
      result.data = response.headers
      result
    else
      #console.log "got response #{body}"
      body = '{}' if not body    
      result.status = 'ok'
      result.data = JSON.parse body
      result

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
    api = "#{@get_obj_api()}#{obj}/"
    console.log "start get_obj #{api}"
    options = {
      url: api
      headers: @get_session_header()
    }
    options.headers['content-type'] = ''
    request.get options,
      (error, response, body) =>
        result = @handle_response error, response, body
        console.log "Finished get_obj_api #{api}"
        callback result

  get_obj_promise: (obj, result, filter="") ->
    deferred = Q.defer()
    result.obj = obj
    api = "#{@get_obj_api()}#{obj}"
    if filter.length
      api += "/#{filter}"
    console.log "start get_obj_promise #{api}"
    options = {
      url: api 
      headers: @get_session_header()
    }
    request.get options,
      (err, res, body) =>
        console.log "get_obj_promise #{obj}"
        if err 
          deferred.reject err
        else
          res = @handle_response_with_result err, res, body, result
          console.log "Finished get_obj_promise #{JSON.stringify result}"
          deferred.resolve res

    return deferred.promise

  get_children_promise: (children, children_result) ->
    queue = []
    children.forEach (ele) =>
      child = {}
      children_result.push child
      queue.push @get_obj_promise ele, child
    queue

  get_connect_promise: (ip, result) ->
    deferred = Q.defer()
    api = "#{@get_connection_api()}/"
    options = {
      url: api
      headers: @get_session_header()
      body: "action=connect&#{ip}"
    }
    options.headers['content-type'] = 'application/x-www-form-urlencoded'
    request.post options,
      (err, res, body) =>
        console.log "get_connect_promise #{ip}"
        if err 
          deferred.reject err
        else
          res = @handle_response_with_result err, res, body, result
          console.log "Finished get_obj_promise #{JSON.stringify result}"
          deferred.resolve res

    return deferred.promise

  connect: (ip, callback) ->
    console.log "connect #{ip}"
    queue = []
    result = {}
    queue.push @get_connect_promise ip, {}
    console.log "Got queue #{queue}"
    Q.all queue
      .then (ful) =>
        queue = [] 
        queue.push @get_obj_promise 'physicalchassismanager1', {}, "?Children-PhysicalChassis"
        console.log "Got queue 1 #{queue}"
        Q.all queue
      .then (ful) =>
        console.log "Got physicalchassismanager1: #{JSON.stringify ful}"
        chassis_list = ful[0].data.split " "
        queue = @get_children_promise chassis_list, []
        console.log "Got queue 2 #{queue}"
        Q.all queue
      .then (ful) =>
        console.log "Got physical chassis: #{JSON.stringify ful}"
        for chassis in ful
          if chassis.data.Hostname == ip
            found_chassis = chassis
            break

        if found_chassis
          for key, val of found_chassis
            result[key] = val

          all_children = found_chassis.data.children?.split " "
          tm_list = (child for child in all_children when (child.indexOf "physicaltestmodule") == 0)
          result.children = []
          queue = @get_children_promise tm_list, result.children
          Q.all queue
      .then (ful) =>
        console.log "Got tm #{JSON.stringify ful, null, 2}"
        queue = []
        for tm in ful
          if tm.data.children?
            portgroup_list = tm.data.children.split " "
            tm.children = []
            queue = queue.concat (@get_children_promise portgroup_list, tm.children)
        Q.all queue
      .fail (error) =>
        console.log "Got error #{error}"
      .finally () =>
        console.log "Final result #{JSON.stringify result, null, 2}"
        callback result
        # res.setHeader('Content-Type', 'application/json');
        # res.send JSON.stringify result, null, 2


module.exports = BllApi