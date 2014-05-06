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
    2.  Lookup any port to see if this port exists    
    3.  If yes, detach and delete
    4.  If not, ignore  
###

class ReleaseCmd
  constructor: (@bllapi,
                @data,
                @callback)->
    @_result = {}
    @_port_list = []
    
  run: =>
    console.log "run ReleaseCmd data: #{JSON.stringify @data}"
    async.waterfall [
      @_init
      @_get_port_hnds
      @_get_port_info
      @_detach_port
      @_delete_port
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

  _detach_port: (current_ports, next_task) =>
    detach_plist = []
    for port in current_ports
      if port.data.Name? and port.data.Online is "true"
        if port.data.Location in @_port_list
          detach_plist.push port.obj

    if detach_plist.length
      detach_options =
        PortList: detach_plist.join " "
      @bllapi.perform "DetachPorts", detach_options, (result) =>
        if result.status == 'failed'
          next_task result
        else
          next_task null, detach_plist 
    else
      next_task null, []        

  _delete_port: (detached_port_list, next_task) =>
    if detached_port_list.length
      queue = []
      for port in detached_port_list
        queue.push @bllapi.delete_promise port, {} 
      Q.all queue
        .then (ful) =>          
          next_task null, ful
        .fail (error) =>
          next_task {status: "failed", data: "#{error}"}
    else
      next_task null, []

  _end_task: (err, result) =>
    if err
      @callback err
    else
      @callback @_result

module.exports = ReleaseCmd