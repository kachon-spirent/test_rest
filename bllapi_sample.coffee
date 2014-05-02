# args = process.argv.slice 2
# console.log args
Q = require 'q'

bllapi = require "./lib/bllapi"
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
  queue.push bll_api._get_promise 'project1', {}
  Q.all queue
    .then (ful) ->
      console.log "#{JSON.stringify ful}"
      queue = [] 
      queue.push bll_api._get_promise 'project1', {}, "Name", "Active"
      Q.all queue
    .then (ful) ->
      console.log "#{JSON.stringify ful}"
      queue = [] 
      queue.push bll_api._create_promise 'port', {}, {"under": "project1"}, {"Name": "My Port"}
      Q.all queue
    .then (ful) ->
      console.log "#{JSON.stringify ful}"
      queue = [] 
      queue.push bll_api._config_promise 'port1', {}, {"Name": "My Port2"}
      Q.all queue
    .then (ful) ->
      console.log "#{JSON.stringify ful}"
      queue = [] 
      queue.push bll_api._delete_promise 'port1', {}
      Q.all queue
    .then (ful) ->
      console.log "#{JSON.stringify ful}"
      queue = [] 
      queue.push bll_api._perform_promise 'ApplyToIL', {}
      Q.all queue
    .then (ful) ->
      console.log "#{JSON.stringify ful}"
      console.log 'Done'
    .fail (error) ->
      console.log "Error #{error}"


# bll_api.delete_session (result) ->
#   console.log "after delete session #{JSON.stringify result}" 

# bll_api.create_session (result) ->
#   console.log "after create session #{JSON.stringify result}" 

#test_api_promise()
#test_api()
#restart_session()

# bll_api.create_session()

# bll_api.get 'project1', (result) ->
#  console.log "project 1 #{JSON.stringify result}"

# bll_api.config 'project1', '{"Name": "DDDD"}', (result) ->
#   console.log "After Config project 1 #{JSON.stringify result}"
#   bll_api.get 'project1', (result) ->
#     console.log "After Get project 1 #{JSON.stringify result}"

# bll_api.create 'port', (result) ->
#  console.log "create port #{JSON.stringify result}"

# bll_api.delete 'port1', (result) ->
#   console.log "delete port #{JSON.stringify result}"

# queue = []
# queue.push bll_api._get_promise 'project1', {}
# console.log "#{queue}"

# queue = [] 
# queue.push bll_api._get_promise 'project1', {}, "Children-port"
# run_q queue

# queue = [] 
# queue.push bll_api._config_promise 'project1', {}, {Name: "DDDD"}
# run_q queue

# queue = [] 
# queue.push bll_api._create_promise 'Port', {}, {under: 'project1'}
# run_q queue

# queue = [] 
# queue.push bll_api._delete_promise 'port2', {}
# run_q queue

# queue = [] 
#restart_session()
data = {"portGroupAddresses": ["10.8.232.85/1/1"]}
bll_api.reserve data, (result) ->
  console.log "reserve #{JSON.stringify result, null, 2}"

  bll_api.get 'port1', (result) ->
    console.log "port 1 #{JSON.stringify result}"
#run_q queue