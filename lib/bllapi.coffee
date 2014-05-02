request = require 'request'
qs = require 'querystring'
Q = require 'q'
utils = require './utils'

class BllApi
  constructor: (@host,
                @userid='bllapi', 
                @sessionname='bllapi',
                @sessionid="#{@userid} - #{@sessionname}")->
    
  _get_url: ->
    "http://" + @host

  _get_session_url: ->
    "#{@_get_url()}/stcapi/v1/sessions/"

  _get_obj_url: ->
    "#{@_get_url()}/stcapi/v1/objects/"

  _get_connection_url: ->
    "#{@_get_url()}/stcapi/v1/connections/"

  _get_session_header: ->
    {'X-STC-API-Session': "#{@sessionid}"}

  _get_perform_url: ->
    "#{@_get_url()}/stcapi/v1/perform/"

  _handle_response: (error, response, body) ->
    if error
      #console.log "got error #{error}"
      return {
        status: 'failed'
        data: error
      }
    else if response.statusCode == 500
      #console.log "got error status code #{response.statusCode} #{body}"
      msg = (JSON.parse body).message
      return {
        status: 'failed'
        data: msg    
      }
    else if response.statusCode >= 400
      #console.log "got error status code #{response.statusCode} #{body}"
      return {
        status: 'failed'
        data: JSON.parse body      
      }
    else
      #console.log "got response #{body}"
      body = '{}' if not body    
      return {
        status: 'ok'
        data: JSON.parse body
      }

  _handle_response_with_result: (error, response, body, result) ->   
    if error
      #console.log "got error #{error}"
      result.status = 'failed'
      result.data = error
      result
    else if response.statusCode == 500
      #console.log "got error status code #{response.statusCode} #{body}"
      msg = (JSON.parse body).message
      result.status = 'failed'
      result.data = msg
      result
    else if response.statusCode >= 400
      #console.log "got error status code #{response.statusCode} #{body}"
      result.status = 'failed'
      result.data = JSON.parse body
      result
    else
      #console.log "got response #{body}"
      body = '{}' if not body    
      result.status = 'ok'
      result.data = JSON.parse body
      result

  _get_promise: (obj, result, prop...) =>
    deferred = Q.defer()
    result.obj = obj
    options = @_format_get_options obj, prop...
    request.get options,
      (err, res, body) =>
        if err 
          deferred.reject err
        else
          res = @_handle_response_with_result err, res, body, result
          deferred.resolve res

    return deferred.promise

  _config_promise: (obj, result, prop...) =>
    deferred = Q.defer()
    result.obj = obj
    options = @_format_config_options obj, prop...
    request.put options,
      (err, res, body) =>
        if err 
          deferred.reject err
        else
          res = @_handle_response_with_result err, res, body, result
          deferred.resolve res

    return deferred.promise

  _create_promise: (obj, result, prop...) =>
    deferred = Q.defer()
    result.obj = obj
    options = @_format_create_options obj, prop...
    request.post options,
      (err, res, body) =>
        if err 
          deferred.reject err
        else
          res = @_handle_response_with_result err, res, body, result
          deferred.resolve res

    return deferred.promise

  _delete_promise: (obj, result) =>
    deferred = Q.defer()
    result.obj = obj
    options = @_format_delete_options obj
    request.del options,
      (err, res, body) =>
        if err 
          deferred.reject err
        else
          res = @_handle_response_with_result err, res, body, result
          deferred.resolve res

    return deferred.promise

  _perform_promise: (command, result, prop...) =>
    deferred = Q.defer()
    result.obj = command
    options = @_format_perform_options command, prop...
    request.post options,
      (err, res, body) =>
        if err 
          deferred.reject err
        else
          res = @_handle_response_with_result err, res, body, result
          deferred.resolve res

    return deferred.promise

  _get_children_promise: (children, children_result) ->
    queue = []
    children.forEach (ele) =>
      child_result = {}
      children_result.push child_result
      queue.push @_get_promise ele, child_result
    queue

  _get_connect_promise: (ip, result) ->
    deferred = Q.defer()
    api = "#{@_get_connection_url()}/"
    options = {
      url: api
      headers: @_get_session_header()
      body: "action=connect&#{ip}"
    }
    options.headers['content-type'] = 'application/x-www-form-urlencoded'
    request.post options,
      (err, res, body) =>
        console.log "get_connect_promise #{ip}"
        if err 
          deferred.reject err
        else
          res = @_handle_response_with_result err, res, body, result
          if res.status == 'ok'
            deferred.resolve res
          else
            deferred.reject res.data

    return deferred.promise

  _get_chassis_info: (ip, callback) ->
    console.log "_get_chassis_info #{ip}"
    queue = []
    result = {}
    queue.push @_get_connect_promise ip, {}
    console.log "Got queue #{queue}"
    Q.all queue
      .then (ful) =>
        queue = [] 
        queue.push @_get_promise 'physicalchassismanager1', {}, "Children-PhysicalChassis"
        console.log "Got queue 1 #{queue}"
        Q.all queue
      .then (ful) =>
        console.log "Got physicalchassismanager1: #{JSON.stringify ful}"
        chassis_list = ful[0].data.split " "
        queue = @_get_children_promise chassis_list, []
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
          queue = @_get_children_promise tm_list, result.children
          Q.all queue
      .then (ful) =>
        console.log "Got tm #{JSON.stringify ful, null, 2}"
        queue = []
        for tm in ful
          if tm.data.children?
            portgroup_list = tm.data.children.split " "
            tm.children = []
            queue = queue.concat (@_get_children_promise portgroup_list, tm.children)
        Q.all queue
      .then () =>
        console.log "Final result #{JSON.stringify result, null, 2}"
        callback result
      .fail (error) =>
        console.log "Got error #{error}"
        callback {status: "failed", data: "#{error}"}


  _format_get_options: (obj, prop...) =>
    url = "#{@_get_obj_url()}#{obj}/"
    options = {
      url: url + "?#{prop.join '&'}"
      headers: @_get_session_header()
    }
    options.headers['content-type'] = ''
    options

  _format_config_options: (obj, prop...) =>
    api = "#{@_get_obj_url()}#{obj}/"
    form = {}
    for p in prop
        for key, val of p
          form[key] = val
    options = {
      url: api 
      headers: @_get_session_header()
      form: form
    }
    options

  _format_create_options: (obj_type, prop...) =>
    api = "#{@_get_obj_url()}"
    form = {}
    for p in prop
        for key, val of p
          form[key] = val
    form.object_type = obj_type
    options = {
      url: api 
      headers: @_get_session_header()
      form: form
    }
    options

  _format_delete_options: (obj) =>
    api = "#{@_get_obj_url()}#{obj}/"
    options = {
      url: api 
      headers: @_get_session_header()
    }

  _format_perform_options: (command, prop...) =>
    api = "#{@_get_perform_url()}"
    form = {}
    for p in prop
        for key, val of p
          form[key] = val
    form.command = command
    options = {
      url: api 
      headers: @_get_session_header()
      form: form
    }
    options

  create_session: (callback) ->
    api = @_get_session_url()
    form = 
      userid: @userid
      sessionname: @sessionname
    console.log "start create_session #{api}"
    request.post {
      url: api
      form: form
      },
      (error, response, body) =>
        result = @_handle_response error, response, body
        if not result.status
          console.log "Failed to created session"
        else
          @sessionid = result.data.session_id
          console.log "Created session: #{result.data} #{@sessionid}"
          callback result


  delete_session: (callback) =>
    api = "#{@_get_session_url()}#{@sessionid}/"
    console.log "start delete_session #{api}"
    request.del {
      url: api
    },
    (error, response, body) =>
        result = @_handle_response error, response, body
        console.log "Finished delete_session #{api}"
        callback result

  get_all_session: ->
    api = @_get_session_url()
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

  get: (obj, prop..., callback) =>
    options = @_format_get_options obj, prop...
    request.get options,
      (error, response, body) =>
        result = @_handle_response error, response, body
        callback result

  config: (obj, prop..., callback) =>
    options = @_format_config_options obj, prop...
    request.put options,
      (error, response, body) =>
        result = @_handle_response error, response, body
        console.log "Finished config"
        callback result

  create: (obj, prop..., callback) =>
    options = @_format_create_options obj, prop...
    request.post options,
      (error, response, body) =>
        result = @_handle_response error, response, body
        console.log "Finished create"
        callback result

  delete: (obj, callback) =>
    options = @_format_delete_options obj
    request.del options,
      (error, response, body) =>
        result = @_handle_response error, response, body
        console.log "Finished delete"
        callback result

  perform: (command, prop..., callback) =>
    options = @_format_perform_options command, prop...
    request.post options,
      (error, response, body) =>
        result = @_handle_response error, response, body
        console.log "Finished perform"
        callback result

  connect: (ip, callback) ->
    console.log "connect #{ip}"
    @_get_chassis_info ip, callback

  disconnect: (ip, callback) ->
    console.log "disconnect #{ip}"
    api = "#{@_get_connection_url()}/"
    options = {
      url: api
      headers: @_get_session_header()
      body: "action=disconnect&#{ip}"
    }
    options.headers['content-type'] = 'application/x-www-form-urlencoded'
    request.post options,
      (error, response, body) =>
        result = @_handle_response error, response, body
        callback result

  refresh: (ip, callback) ->
    console.log "connect #{ip}"
    @_get_chassis_info ip, callback

  reserve: (data, callback) ->
    ###
      expected data format
      {"portGroupAddresses": ["10.100.21.7/1/1"]}
                               Chassis/Slot/PortGroup

      1.  Convert Chassis/Slot/PortGroup into CSP 
          Note: from the java code, looks like it is only creating one port and assuming each 
                portgroup contains 2 ports
      2.  Lookup any port to see if we have already create one for this CSP      
      3.  If yes, ignore
      4.  If not, create port and attach    
    ###
    console.log "reserve #{JSON.stringify data}"
    if not data.portGroupAddresses?
      callback {status: "failed", data: "missing portGroupAddresses"}

    if not (data.portGroupAddresses instanceof Array)
      callback {status: "failed", data: "expect array for portGroupAddresses"}

    # convert to csp
    plist = utils.convert_pglist_to_plist data.portGroupAddresses
    queue = []
    queue.push @_get_promise "project1", {}, "Children-Port"
    Q.all queue
      .then (ful) =>
        data = ful[0].data
        if data
          cur_plist = data.split " "
          queue = for port in cur_plist
            @_get_promise port, {}
        Q.all queue
      .then (ful) =>
        filter_list = (port.data.Location for port in ful when port.data.Name? and port.data.Online is "true")
        port_list = (port for port in plist when port not in filter_list)
        #create ports
        if port_list.length
          queue = []
          for new_p in port_list
            params = 
              under: "project1"
              Location: new_p
            queue.push @_create_promise "Port", {}, params
          Q.all queue
            .then (ful) =>
              port_hnd = []
              for port in ful
                port_hnd.push port.data.handle
              attach_options =
                AutoConnect: "True"
                handle: port_hnd.join " "
              queue = []
              queue.push @_perform_promise "AttachPorts", {}, attach_options 
              Q.all queue
      .then (ful) =>
        console.log "Got ful #{JSON.stringify ful}"
        callback {status: "ok", data: ""}
      .fail (error) =>
        console.log "Got error #{error}"
        callback {status: "failed", data: "#{error}"}

    #callback {status: "ok", data: ""}

  release: (data, callback) ->
    ###
      expected data format
      {"portGroupAddresses": ["10.100.21.7/1/1"]}
                               Chassis/Slot/PortGroup

      1.  Convert Chassis/Slot/PortGroup into CSP 
          Note: from the java code, looks like it is only creating one port and assuming each 
                portgroup contains 2 ports
      2.  Lookup any port to see if this port exists    
      3.  If yes, detach and delete
      4.  If not, ignore  
    ###
    console.log "reserve #{JSON.stringify data}"
    if not data.portGroupAddresses?
      callback {status: "failed", data: "missing portGroupAddresses"}

    if not (data.portGroupAddresses instanceof Array)
      callback {status: "failed", data: "expect array for portGroupAddresses"}

    # convert to csp
    plist = utils.convert_pglist_to_plist data.portGroupAddresses
    queue = []
    queue.push @_get_promise "project1", {}, "Children-Port"
    Q.all queue
      .then (ful) =>
        data = ful[0].data
        if data
          cur_plist = data.split " "
          queue = for port in cur_plist
            @_get_promise port, {}
        Q.all queue
      .then (ful) =>
        filter_list = (port.data.Location for port in ful when port.data.Name? and port.data.Online is "true")
        port_list = (port for port in plist when port in filter_list)
        #detach ports
        if new_list.length
          queue = []
          for new_p in new_list
            params = 
              under: "project1"
              Location: new_p
            queue.push @_create_promise "Port", {}, params
          Q.all queue
            .then (ful) =>
              port_hnd = []
              for port in ful
                port_hnd.push port.data.handle
              attach_options =
                AutoConnect: "True"
                handle: port_hnd.join " "
              queue = []
              queue.push @_perform_promise "AttachPorts", {}, attach_options 
              Q.all queue
      .then (ful) =>
        console.log "Got ful #{JSON.stringify ful}"
        callback {status: "ok", data: ""}
      .fail (error) =>
        console.log "Got error #{error}"
        callback {status: "failed", data: "#{error}"}

module.exports = BllApi