express = require "express"
restapi = require "../lib/restapi"
Q = require 'q'
router = express.Router()
rest_api = new restapi '10.8.232.85'

# GET home page. 
router.get "/", (req, res) ->
  rest_api.get_all_session()
  res.render "index",
    title: "Express"
  return

router.get "/create", (req, res) ->
  res.send "receive create"
  rest_api.create_session()
  return

router.get "/delete", (req, res) ->
  res.send "receive delete"
  rest_api.delete_session()
  return

router.get "/system1", (req, res) ->
  res.send "receive system1"
  rest_api.get_obj 'system1', 
    (res) ->
      console.log "got response #{res}"
  return

router.get "/system1_promise", (req, res) ->
  #res.send "hello!!!"
  queue = []
  queue.push rest_api.get_obj_promise 'system1'
  Q.all queue
    .then (ful) ->
      console.log "1st fulfilled #{JSON.stringify ful, null, 2}"
      res.send ful
  return

module.exports = router
