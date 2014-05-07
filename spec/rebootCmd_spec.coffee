utils = require '../lib/utils'
bllapi = require '../lib/bllapi'
RebootCmd = require '../lib/rebootCmd'

describe "RebootCmd", ->

  it "should send reboot command", ->
    bll_api = new bllapi '10.8.227.16'
    cmd = new RebootCmd bll_api, ["1.1.1.1"]
    chassis_hnd_list = ["c1"]
    spyOn bll_api, "get_objs_promise"
    spyOn utils, "run_queue"
      .andCallFake (queue, then_callback, fail_callback) =>
        then_callback [
          {status: "ok", obj: "c1", data: { Hostname: "1.1.1.1"} }
        ]

    spyOn bll_api, "perform"
      .andCallFake (command, prop..., callback) =>
        callback {status: "ok", data: ""}

    cmd._reboot_physical_chassis_hnd chassis_hnd_list, (err, res) =>
      expect bll_api.get_objs_promise
        .toHaveBeenCalledWith ['c1'], []
      expect bll_api.perform.calls[0].args[0]
        .toEqual "RebootEquipment"
      expect bll_api.perform.calls[0].args[1]
        .toEqual {EquipmentList: 'c1'}