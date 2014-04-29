express = require "express"
bllapi = require "../lib/bllapi"
Q = require 'q'
router = express.Router()
bll_api = new bllapi '10.8.227.16'

# GET home page. 
router.get "/", (req, res) ->
  bll_api.get_all_session()
  res.render "index",
    title: "Express"
  return

router.get "/create", (req, res) ->
  bll_api.create_session()
  res.send "done create"
  return

router.get "/delete", (req, res) ->
  bll_api.delete_session()
  res.send "done delete"
  return

router.get "/system1", (req, res) ->
  bll_api.get_obj 'system1', 
    (result) ->
      res.setHeader('Content-Type', 'application/json');
      res.send JSON.stringify result, null, 2
  return

router.get "/system1_promise", (req, res) ->
  queue = []
  result = {}
  queue.push bll_api.get_obj_promise 'system1', result
  Q.all queue
    .then (ful) ->
      children_list = result.data.children.split " "
      result.children = []
      queue = get_children_promise children_list, result.children   
      Q.all queue
        .then (ful) ->
          console.log "Result #{JSON.stringify result, null, 2}"
          res.setHeader('Content-Type', 'application/json');
          res.send JSON.stringify result, null, 2
   return

# router.get "/physicalchassismanager1", (req, res) ->
#   queue = []
#   result = {}
#   queue.push bll_api.get_obj_promise 'physicalchassismanager1', result
#   Q.all queue
#     .then (ful) ->
#       children_list = result.data.children?.split " "
#       if children_list and children_list.length
#         result.children = []
#         queue = get_children_promise children_list, result.children
#         Q.all queue
#           .then (ful) ->
#             console.log "Result #{JSON.stringify result, null, 2}"
#     .finally ->
#       console.log "Result #{JSON.stringify result, null, 2}"
#       console.log "finally!"
#       res.send result
#   return

router.get "/:obj", (req, res) ->
  obj = req.params.obj
  console.log "receive #{obj}"
  queue = []
  result = {}
  queue.push bll_api.get_obj_promise "#{obj}", result
  Q.all queue
    .then (ful) ->
      return
      # children_list = result.data.children?.split " "
      # if children_list and children_list.length
      #   result.children = []
      #   queue = get_children_promise children_list, result.children
      #   Q.all queue
      #     .then (ful) ->
      #       console.log "Result #{JSON.stringify result, null, 2}"
    .finally ->
      console.log "Final result #{JSON.stringify result, null, 2}"
      res.send result
  return

router.get "/connect/:ip", (req, res) ->
  ip = req.params.ip
  console.log "connect #{ip}"
  bll_api.connect ip, (result) ->
      res.setHeader('Content-Type', 'application/json');
      res.send JSON.stringify result, null, 2

module.exports = router
