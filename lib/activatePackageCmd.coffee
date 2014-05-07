request = require 'request'
async = require 'async'
Q = require 'q'
utils = require './utils'

class ActivatePackageCmd
  constructor: (@bllapi,
                @pg_list,
                @test_package)->

  run: (callback) =>
    @callback = callback
    console.log "run ActivatePackageCmd: #{@pg_list} #{@test_package}"
    async.waterfall [
      @_connect
      @_get_physical_chassis_hnds
      @_get_chassis_ip_hnd_list
      @_get_pg_list
      @_activate_test_pacakge
    ],
    @_end_task

  _connect: (next_task) =>
    utils.connect @bllapi, @pg_list, next_task

  _get_physical_chassis_hnds: (next_task) =>
    utils.get_physical_chassis_hnds @bllapi, next_task

  _get_chassis_ip_hnd_list: (hnds, next_task) =>
    utils.get_chassis_ip_hnd_list @bllapi, hnds, next_task

  _get_pg_list: (ip_hnd_list, next_task) =>
    portgroup_ddn_list = []
    if ip_hnd_list.length
      for pg in @pg_list
        [ip, slot, port_group] = pg.split "/"
        for ip_hnd in ip_hnd_list
          if ip == ip_hnd.ip
            portgroup_ddn_list.push "#{ip_hnd.hnd}.physicaltestmodule.#{slot}.physicalportgroup.#{port_group}"
      
      if portgroup_ddn_list.length
        queue = [] 
        queue = @bllapi.get_objs_promise portgroup_ddn_list, [], "Handle"
        utils.run_queue queue,
          (ful) =>
            port_group_hnds = []
            for result in ful
              port_group_hnds.push result.data
            next_task null, port_group_hnds
          (err) =>
            next_task err
    else
      next_task null, []

  _activate_test_pacakge: (port_group_hnds, next_task) =>
    activate_options =
      PortGroupList: port_group_hnds.join " "
      TestPackage: @test_package
    @bllapi.perform "InstallTestPackage", activate_options, (result) =>
      if result.status == 'failed'
        next_task result
      else
        next_task null, result

  _end_task: (err, result) =>
    if err
      @callback err
    else
      @callback result

module.exports = ActivatePackageCmd