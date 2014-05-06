request = require 'request'
async = require 'async'
Q = require 'q'

class RebootCmd
  constructor: (@bllapi,
                @ip_list,
                @callback)->
    @_result = {}

  run: =>
    console.log "run RebootCmd: #{@ip_list}"
    async.waterfall [
      @_connect
      @_get_physical_chassis_hnds
      @_reboot_physical_chassis_hnd
    ],
    @_end_task

  _connect: (next_task) =>
    queue = for ip in @ip_list
      @bllapi.get_connect_promise ip, {}
    Q.all queue
      .then (ful) =>
        for result in ful
          if result.status == 'failed'
            next_task result
            return

        next_task null
      .fail (error) =>
        next_task error

  _get_physical_chassis_hnds: (next_task) =>
    @bllapi.get 'system1.physicalchassismanager', "Children-PhysicalChassis", (res) =>
      if res.status == 'failed'
        next_task res
      else
        hnds = res.data.split " "
        next_task null, hnds

  _reboot_physical_chassis_hnd: (hnds, next_task) =>
    if hnds.length
      queue = [] 
      queue = @bllapi.get_children_promise hnds, []
      Q.all queue
        .then (ful) =>
          for chassis in ful
            if chassis.status == 'failed'
              next_task {status: "failed", data: "#{chassis.data}"}
            if chassis.data.Hostname in @ip_list
              found_chassis = chassis
              break

          if found_chassis
            reboot_options =
              EquipmentList: found_chassis.obj
            @bllapi.perform "RebootEquipment", reboot_options, (result) =>
              if result.status == 'failed'
                next_task result
              else
                next_task null, []
    else
      next_task null, []

  _end_task: (err, result) =>
    if err
      @callback err
    else
      @callback @_result

module.exports = RebootCmd