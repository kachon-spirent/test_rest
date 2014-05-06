request = require 'request'
qs = require 'querystring'
Q = require 'q'
utils = require './utils'
GetChassisInfoCmd = require './getChassisInfoCmd'
ReserveCmd = require './reserveCmd'
ReleaseCmd = require './releaseCmd'
RebootCmd = require './rebootCmd'
ActivatePackageCmd = require './activatePackageCmd'
InstallFirmwareCmd = require './installFirmwareCmd'

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

  config_promise: (obj, result, prop...) =>
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

  create_promise: (obj, result, prop...) =>
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

  delete_promise: (obj, result) =>
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

  perform_promise: (command, result, prop...) =>
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

  get_connect_promise: (ip, result) ->
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

  get_promise: (obj, result, prop...) =>
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

  get_objs_promise: (objs, objs_result, prop...) =>
    queue = []
    objs.forEach (obj) =>
      obj_result = {}
      objs_result.push obj_result
      queue.push @get_promise obj, obj_result, prop...
    queue

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

  connect_chassis: (ip, callback) =>
    api = "#{@_get_connection_url()}/"
    options = {
      url: api
      headers: @_get_session_header()
      body: "action=connect&#{ip}"
    }
    options.headers['content-type'] = 'application/x-www-form-urlencoded'
    request.post options,
      (error, response, body) =>
        result = @_handle_response error, response, body
        console.log "Finished connect_chassis"
        callback result

  connect: (ip, callback) ->
    console.log "connect #{ip}"
    getChassisInfoCmd = new GetChassisInfoCmd @, ip
    getChassisInfoCmd.run callback

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
    console.log "refresh #{ip}"
    getChassisInfoCmd = new GetChassisInfoCmd @, ip
    getChassisInfoCmd.run callback

  reserve: (data, callback) ->
    console.log "reserve"
    reserveCmd = new ReserveCmd @, data
    reserveCmd.run callback

  release: (data, callback) ->
    console.log "release"
    reserveCmd = new ReleaseCmd @, data
    reserveCmd.run callback

  reboot: (ip, callback) ->
    console.log "reboot"
    reserveCmd = new RebootCmd @, ip
    reserveCmd.run callback

  check_command_status: (sequencer, cmd, callback) ->
    console.log "check_command_status"
    @get sequencer, "state", (result) =>
      if result.data == 'IDLE'
        @get cmd, "State", (result) =>
          if result.status == "failed"
            callback result
            return

          if result.data == "FAILED"
            callback {status: "failed", data: "Failed"}
          else
            callback {status: "ok", data: "Success"}
      else
        callback {status: "ok", data: result.data}

  activate_package: (port_group_list, test_pacakge, callback) =>
    console.log "activate package"
    pg_data = 
      portGroupAddresses: port_group_list
    releaseCmd = new ReleaseCmd @, pg_data
    releaseCmd.run (result) =>
      console.log "Finished ReleaseCmd"
      if result.status == 'ok'    
        activatePackageCmd = new ActivatePackageCmd @, port_group_list, test_pacakge
        activatePackageCmd.run (result) =>
          console.log "Finished ActivatePackageCmd"
          if result.status == 'ok'
            reserveCmd = new ReserveCmd @, pg_data
            reserveCmd.run (result) =>
              console.log "Finished ReleaseCmd"
              if result.status == 'ok'
                callback {status: "ok", data: ""}
              else
                callback result
          else
            callback result
      else      
        callback result

  install_firmware: (ip_list, version, callback) =>
    installCmd = new InstallFirmwareCmd @, ip_list, version
    installCmd.run (result) =>
      callback result
      
module.exports = BllApi