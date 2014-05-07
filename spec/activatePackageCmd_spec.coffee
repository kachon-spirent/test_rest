utils = require '../lib/utils'
bllapi = require '../lib/bllapi'
ActivatePackageCmd = require '../lib/activatePackageCmd'

describe "ActivatePackageCmd", ->

  it "should return port group hnds", ->
    bll_api = new bllapi '10.8.227.16'
    cmd = new ActivatePackageCmd bll_api, ["1.1.1.1/1/1"]
    ip_hnd_list = [
      {ip: "1.1.1.1", hnd: "c1"}
    ]
    spyOn bll_api, "get_objs_promise"
    spyOn utils, "run_queue"
      .andCallFake (queue, then_callback, fail_callback) =>
        then_callback [
          {status: "ok", obj: "c1", data: 'c1' }
        ]

    cmd._get_pg_list ip_hnd_list, (err, res) =>
      expect res
        .toEqual ["c1"]
      expect bll_api.get_objs_promise
        .toHaveBeenCalledWith ['c1.physicaltestmodule.1.physicalportgroup.1'], [], 'Handle'
