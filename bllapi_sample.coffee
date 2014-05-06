# args = process.argv.slice 2
# console.log args
Q = require 'q'

bllapi = require "./lib/bllapi"
GetChassisInfoCmd = require "./lib/getChassisInfoCmd"
bll_api = new bllapi '10.8.227.16'

run_q = (queue) ->
  Q.all queue
  .then (ful) =>
    console.log "finish queue #{JSON.stringify ful}"
  .fail (error) =>
    console.log "Got error #{error}"

restart_session = ->
  bll_api.delete_session (result) ->
    console.log "delete_session 1 #{JSON.stringify result}"
    bll_api.create_session (result) ->
      console.log "create_session 1 #{JSON.stringify result}"

test_api = ->
  # bll_api.delete_session()
  # bll_api.create_session()

  bll_api.perform 'ResetConfig', {"Config": "System1"}, (result) ->
    console.log "ResetConfig 1 #{JSON.stringify result}"

    bll_api.get 'project1', (result) ->
      console.log "project 1 #{JSON.stringify result}"

    bll_api.get 'project1', "Name", "Active", "Children-port", (result) ->
      console.log "project 1 #{JSON.stringify result}"

    bll_api.create 'port', {"under": "project1"}, {"Name": "My Port"}, (result) ->
      console.log "create port #{JSON.stringify result}"

      bll_api.config 'port1', {"Name": "My Port2"}, (result) ->
        console.log "config port #{JSON.stringify result}"

        bll_api.delete 'port1', (result) ->
          console.log "delete port #{JSON.stringify result}"

          bll_api.perform 'ApplyToIL', (result) ->
            console.log "Apply to IL #{JSON.stringify result}"

test_api_promise = ->
  #bll_api.create_session()

  queue = [] 
  queue.push bll_api.get_promise 'project1', {}
  Q.all queue
    .then (ful) ->
      console.log "#{JSON.stringify ful}"
      queue = [] 
      queue.push bll_api.get_promise 'project1', {}, "Name", "Active"
      Q.all queue
    .then (ful) ->
      console.log "#{JSON.stringify ful}"
      queue = [] 
      queue.push bll_api.create_promise 'port', {}, {"under": "project1"}, {"Name": "My Port"}
      Q.all queue
    .then (ful) ->
      console.log "#{JSON.stringify ful}"
      queue = [] 
      queue.push bll_api.config_promise 'port1', {}, {"Name": "My Port2"}
      Q.all queue
    .then (ful) ->
      console.log "#{JSON.stringify ful}"
      queue = [] 
      queue.push bll_api.delete_promise 'port1', {}
      Q.all queue
    .then (ful) ->
      console.log "#{JSON.stringify ful}"
      queue = [] 
      queue.push bll_api.perform_promise 'ApplyToIL', {}
      Q.all queue
    .then (ful) ->
      console.log "#{JSON.stringify ful}"
      console.log 'Done'
    .fail (error) ->
      console.log "Error #{error}"

test_bllapi = ->
  ip1 = '10.8.234.99'
  ip2 = '10.8.233.186'
  pg1 = "#{ip1}/1/1"
  pg2 = "#{ip2}/1/1"
  data = {"portGroupAddresses": ["#{ip1}"]}

  # bll_api.connect_chassis ip, (result) ->
  #   console.log "connect #{JSON.stringify result, null, 2}"
  # bll_api.connect ip, (result) ->
  #   console.log "connect #{JSON.stringify result, null, 2}"
  #   bll_api.reserve data, (result) ->
  #     console.log "reserve done #{JSON.stringify result, null, 2}"
  #     bll_api.release data, (result) ->
  #       console.log "release #{JSON.stringify result, null, 2}"
  # bll_api.reboot [ip], (result) ->
  #   console.log "reboot done #{JSON.stringify result, null, 2}"
  # bll_api.check_command_status "system1.sequencer", "cmd1", (result) ->
  #   console.log "check_command_status done #{JSON.stringify result, null, 2}"
  # bll_api.activate_package [pg1], "stc", (result) ->
  #   console.log "activate package #{JSON.stringify result, null, 2}"
  bll_api.install_firmware [ip1], "2.0.0", (result) ->
    console.log "install_firmware #{JSON.stringify result, null, 2}"

test_bllapi()

