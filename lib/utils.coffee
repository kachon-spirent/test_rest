class Utils
  @PORTS_PER_PORT_GROUP = 2

  @convert_pglist_to_plist: (pglist) ->
    #console.log "convert_pglist_to_plist #{pglist}"
    plist = for pg in pglist
      csp = pg.split "/"
      csp[2] = csp[2] * @PORTS_PER_PORT_GROUP - 1
      "//" + (csp.join "/")


module.exports = Utils