utils = require '../lib/utils'
bllapi = require '../lib/bllapi'

describe "Utils", ->
  it "should have set port per group to 2" , ->
    expect utils.PORTS_PER_PORT_GROUP
      .toBe 2

  it "should have converted pglist to plist", ->
    pglist = ['1.1.1.1/1/1', '1.1.1.1/1/2']
    expected_plist = ['//1.1.1.1/1/1', '//1.1.1.1/1/3']
    plist = utils.convert_pglist_to_plist pglist
    expect plist
      .toEqual expected_plist

  it "should have return a list of physical chassis handle", ->
    bll_api = new bllapi '10.8.227.16'
    spyOn bll_api, "get"
      .andCallFake (obj, prop..., callback) ->
        callback {status: 'ok', data: "chassis1 chassis2"}
    
    utils.get_physical_chassis_hnds bll_api, (err, res) =>
      expect res
        .toEqual ["chassis1", "chassis2"]

    expect bll_api.get
      .toHaveBeenCalled()

  it "should have return a ip_hnd_list", ->
    bll_api = new bllapi '10.8.227.16'
    spyOn bll_api, "get_objs_promise"
    spyOn utils, "run_queue"
      .andCallFake (queue, then_callback, fail_callback) =>
        then_callback [
          {status: "ok", obj: "c1", data: {Hostname: '1.1.1.1'} }
          {status: "ok", obj: "c2", data: {Hostname: '1.1.1.2'} }
        ]
    utils.get_chassis_ip_hnd_list bll_api, ["c1", "c2"], (err, res) =>
      expect res
        .toEqual [
          {ip: '1.1.1.1', hnd: 'c1'}
          {ip: '1.1.1.2', hnd: 'c2'}
        ]