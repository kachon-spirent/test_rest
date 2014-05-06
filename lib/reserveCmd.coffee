request = require 'request'
async = require 'async'
Q = require 'q'
utils = require './utils'

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

class ReserveCmd
  constructor: (@bllapi,
                @data,
                @callback)->
    @_result = {}
    @_port_list = []
    
  run: =>
    console.log "run ReserveCmd data: #{JSON.stringify @data}"
    async.waterfall [
      @_init
      @_get_port_hnds
      @_get_port_info
      @_create_port
      @_attach_port
    ],
    @_end_task

  _init: (next_task) =>
    if not @data.portGroupAddresses?
      next_task {status: "failed", data: "missing portGroupAddresses"}
      return

    if not (@data.portGroupAddresses instanceof Array)
      next_task {status: "failed", data: "expect array for portGroupAddresses"}
      return

    # convert to csp
    @_port_list = utils.convert_pglist_to_plist @data.portGroupAddresses
    next_task null

  _get_port_hnds: (next_task) =>
    @bllapi.get "system1.project", "Children-Port", (result) =>
      if result.status == 'failed'
        next_task result
      else
        current_port_hnds = []
        if result.data != ""
          current_port_hnds = result.data.split " "
        next_task null, current_port_hnds

  _get_port_info: (current_port_hnds, next_task) =>
    if current_port_hnds.length > 0
      queue = for port in current_port_hnds
        @bllapi.get_promise port, {}
      Q.all queue
        .then (ful) =>
          next_task null, ful
        .fail (error) =>
          next_task {status: "failed", data: "#{error}"}
    else
      next_task null, []

  _create_port: (current_port_info, next_task) =>
    if current_port_info.length >= 0
      filter_list = (port.data.Location for port in current_port_info \
        when port.data.Name? and port.data.Online is "true")
      plist = (port for port in @_port_list when port not in filter_list)
      #create ports
      console.log "plist #{plist}"
      if plist.length
        queue = []
        for new_p in plist
          params = 
            under: "project1"
            Location: new_p
          queue.push @bllapi.create_promise "Port", {}, params
        Q.all queue
          .then (ful) =>
            next_task null, ful
          .fail (error) =>
            next_task {status: "failed", data: "#{error}"}
    else
      next_task null, []

  _attach_port: (new_ports, next_task) =>
    if new_ports.length
      port_hnd = []
      for port in new_ports
        port_hnd.push port.data.handle
      attach_options =
        AutoConnect: "True"
        PortList: port_hnd.join " "
      @bllapi.perform "AttachPorts", attach_options, (result) =>
        if result.status == 'failed'
          next_task result
        else
          next_task null, result
    else
      next_task null

  _end_task: (err, result) =>
    if err
      @callback err
    else
      @callback @_result

module.exports = ReserveCmd