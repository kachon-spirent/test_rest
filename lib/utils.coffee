async = require 'async'
Q = require 'q'

class Utils
  @PORTS_PER_PORT_GROUP = 2

  @run_queue: (queue, then_callback, fail_callback) =>
    Q.all queue
      .then then_callback
      .fail fail_callback

  @convert_pglist_to_plist: (pglist) ->
    #console.log "convert_pglist_to_plist #{pglist}"
    plist = for pg in pglist
      csp = pg.split "/"
      csp[2] = csp[2] * @PORTS_PER_PORT_GROUP - 1
      "//" + (csp.join "/")

  @connect: (bllapi, pg_list, next_task) =>
    #pg_list accepts port group list or ip list
    queue = for pg in pg_list
      ip = (pg.split "/")[0]
      bllapi.get_connect_promise ip, {}
    Q.all queue
      .then (ful) =>
        for result in ful
          if result.status == 'failed'
            next_task result
            return

        next_task null
      .fail (error) =>
        next_task error

  @get_physical_chassis_hnds: (bllapi, next_task) =>
    bllapi.get 'system1.physicalchassismanager', "Children-PhysicalChassis", (res) =>
      if res.status == 'failed'
        next_task res
      else
        hnds = res.data.split " "
        next_task null, hnds

  @get_chassis_ip_hnd_list: (bllapi, hnds, next_task) =>
    if hnds.length
      queue = [] 
      queue = bllapi.get_objs_promise hnds, []
      ip_hnd_list = []

      @run_queue queue,
        (ful) =>
          for chassis in ful
            if chassis.status == 'failed'
              next_task {status: "failed", data: "#{chassis.data}"}
            else
              ip_hnd_list.push {ip: chassis.data.Hostname, hnd: chassis.obj}

          next_task null, ip_hnd_list
        (err) =>

    else
      next_task null, []

module.exports = Utils