request = require 'request'
async = require 'async'
Q = require 'q'
utils = require './utils'

class InstallFirmwareCmd
  constructor: (@bllapi,
                @ip_list
                @install_path,
                @version)->

  run: (callback) =>
    @callback = callback
    console.log "run InstallFirmwareCmd: #{@ip_list} #{@install_path} #{@version}"
    async.waterfall [
      @_connect
      @_get_physical_chassis_hnds
      @_get_chassis_ip_hnd_list
      @_get_install_chassis_hnds
      @_install
    ],
    @_end_task

  _connect: (next_task) =>
    utils.connect @bllapi, @ip_list, next_task

  _get_physical_chassis_hnds: (next_task) =>
    utils.get_physical_chassis_hnds @bllapi, next_task

  _get_chassis_ip_hnd_list: (hnds, next_task) =>
    utils.get_chassis_ip_hnd_list @bllapi, hnds, next_task

  _get_install_chassis_hnds: (ip_hnd_list, next_task) =>
    install_chassis_hnds = []
    if ip_hnd_list.length
      for ip in @ip_list
        for ip_hnd in ip_hnd_list
          if ip == ip_hnd.ip
            install_chassis_hnds.push ip_hnd.hnd
      
    next_task null, install_chassis_hnds

  _install: (install_chassis_hnds, next_task) =>
    if install_chassis_hnds.length
      install_options =
        EquipmentList: install_chassis_hnds.join " "
        Version: @version
      @bllapi.perform "InstallRawImage", install_options, (result) =>
        if result.status == 'failed'
          next_task result
        else
          next_task null, result
    else
      next_task null, {status: "ok", data: ""}

  _end_task: (err, result) =>
    if err
      @callback err
    else
      @callback result

module.exports = InstallFirmwareCmd