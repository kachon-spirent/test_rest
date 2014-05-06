request = require 'request'
async = require 'async'
Q = require 'q'

class GetChassisInfoCmd
  constructor: (@bllapi,
                @ip)->
    @_result = {}
    

  run: (callback) =>
    @callback = callback
    console.log "run GetChassisInfoCmd ip: #{@ip}"
    async.waterfall [
      @_connect
      @_get_physical_chassis_hnds
      @_get_physical_chassis_hnd
      @_get_physical_tm
      @_get_physical_pg
    ],
    @_end_task

  _connect: (next_task) =>
    @bllapi.connect_chassis @ip, (result) =>
      if result.status == 'failed'
        next_task result
      else
        next_task null

  _get_physical_chassis_hnds: (next_task) =>
    @bllapi.get 'system1.physicalchassismanager', "Children-PhysicalChassis", (res) =>
      if res.status == 'failed'
        next_task res
      else
        hnds = res.data.split " "
        next_task null, hnds

  _get_physical_chassis_hnd: (hnds, next_task) =>
    queue = [] 
    queue = @bllapi.get_objs_promise hnds, []
    Q.all queue
      .then (ful) =>
        for chassis in ful
          if chassis.status == 'failed'
            next_task {status: "failed", data: "#{chassis.data}"}
          if chassis.data.Hostname == @ip
            found_chassis = chassis
            break

        if found_chassis
          for key, val of found_chassis
            @_result[key] = val

          all_children = found_chassis.data.children?.split " "
          tm_list = (child for child in all_children when (child.indexOf "physicaltestmodule") == 0)
          next_task null, @_result, tm_list
        else
          next_task {status: "failed", data: "chassis is not found"}
      .fail (error) =>
        next_task {status: "failed", data: "#{error}"}

  _get_physical_tm: (chassis_result, tm_list, next_task) =>
      portgroup_list = []
      if tm_list.length > 0
        chassis_result.children = []
        queue = []
        queue = @bllapi.get_objs_promise tm_list, chassis_result.children
        Q.all queue
          .then (ful) =>
            for tm in ful
              if tm.data.children?
                portgroup_data = 
                  tm_result: tm
                  portgroup: tm.data.children.split " "
                portgroup_list.push portgroup_data
            
            next_task null, portgroup_list
        .fail (error) =>
          next_task {status: "failed", data: "#{error}"}
      else
        next_task null, {}

  _get_physical_pg: (portgroup_list, next_task) =>
      if portgroup_list.length > 0
        queue = []
        for pg in portgroup_list
          pg.tm_result.children = []
          queue = queue.concat @bllapi.get_objs_promise pg.portgroup, pg.tm_result.children
        Q.all queue
          .then (ful) =>          
            next_task null, ful
          .fail (error) =>
            next_task {status: "failed", data: "#{error}"}
      else
        next_task null, {}

  _end_task: (err, result) =>
    if err
      @callback err
    else
      @callback @_result

module.exports = GetChassisInfoCmd