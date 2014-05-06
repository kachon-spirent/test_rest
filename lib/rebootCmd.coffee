request = require 'request'
async = require 'async'
Q = require 'q'
utils = require './utils'

class RebootCmd
  constructor: (@bllapi,
                @ip_list)->
    @_result = {}

  run: (callback) =>
    @callback = callback
    console.log "run RebootCmd: #{@ip_list}"
    async.waterfall [
      @_connect
      @_get_physical_chassis_hnds
      @_reboot_physical_chassis_hnd
    ],
    @_end_task

  _connect: (next_task) =>
    utils.connect @bllapi, @ip_list, next_task

  _get_physical_chassis_hnds: (next_task) =>
    utils.get_physical_chassis_hnds @bllapi, next_task

  _reboot_physical_chassis_hnd: (hnds, next_task) =>
    if hnds.length
      queue = [] 
      queue = @bllapi.get_objs_promise hnds, []
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