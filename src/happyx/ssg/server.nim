## # Server
## 
## Provides a Server object that encapsulates the server's address, port, and logger.
## Developers can customize the logger's format using the built-in newConsoleLogger function.
## HappyX provides two options for handling HTTP requests: httpx and asynchttpserver.
## Developers can define which library to use by setting the httpx flag.
## 
## 

import
  macros,
  strutils,
  strtabs,
  strformat,
  asyncdispatch,
  asyncfile,
  logging,
  terminal,
  colors,
  regex,
  json,
  os,
  websocketx,
  ../spa/tag,
  ../private/cmpltime

export
  strutils,
  strtabs,
  strformat,
  asyncdispatch,
  asyncfile,
  logging,
  terminal,
  colors,
  regex,
  json,
  os,
  websocketx


when defined(httpx):
  import
    options,
    httpx
  export
    options,
    httpx
else:
  import asynchttpserver
  export asynchttpserver


type
  Server* = object
    address*: string
    port*: int
    logger*: Logger
    when defined(httpx):
      instance*: Settings
    else:
      instance*: AsyncHttpServer


var pointerServer: ptr Server


proc ctrlCHook() {.noconv.} =
  quit(QuitSuccess)

proc onQuit() {.noconv.} =
  echo "Shutdown ..."
  when not defined(httpx):
    if not pointerServer.isNil():
      pointerServer[].instance.close()
      echo "Server closed"


setControlCHook(ctrlCHook)
addQuitProc(onQuit)


func fgColored*(text: string, clr: ForegroundColor): string {.inline.} =
  ## This function takes in a string of text and a ForegroundColor enum
  ## value and returns the same text with the specified color applied.
  ## 
  ## Arguments:
  ## - `text`: A string value representing the text to apply color to.
  ## - `clr`: A ForegroundColor enum value representing the color to apply to the text.
  ## 
  ## Return value:
  ## - The function returns a string value with the specified color applied to the input text.
  runnableExamples:
    echo fgColored("Hello, world!", fgRed)
  ansiForegroundColorCode(clr) & text & ansiResetCode


func fgStyled*(text: string, style: Style): string {.inline.} =
  ## This function takes in a string of text and a Style enum
  ## value and returns the same text with the specified style applied.
  ## 
  ## Arguments:
  ## - `text`: A string value representing the text to apply style to.
  ## - `clr`: A Style enum value representing the style to apply to the text.
  ## 
  ## Return value:
  ## - The function returns a string value with the specified style applied to the input text.
  runnableExamples:
    echo fgStyled("Hello, world!", styleBlink)
  ansiStyleCode(style) & text & ansiResetCode


proc newServer*(address: string = "127.0.0.1", port: int = 5000): Server =
  ## This procedure creates and returns a new instance of the `Server` object,
  ## which listens for incoming connections on the specified IP address and port.
  ## If no address is provided, it defaults to `127.0.0.1`,
  ## which is the local loopback address.
  ## If no port is provided, it defaults to `5000`.
  ## 
  ## Parameters:
  ## - `address` (optional): A string representing the IP address that the server should listen on.
  ##   Defaults to `"127.0.0.1"`.
  ## - `port` (optional): An integer representing the port number that the server should listen on.
  ##   Defaults to `5000`.
  ## 
  ## Returns:
  ## - A new instance of the `Server` object.
  runnableExamples:
    var s = newServer()
    assert s.address == "127.0.0.1"
  result = Server(
    address: address,
    port: port,
    logger: newConsoleLogger(lvlInfo, fgColored("[$date at $time]:$levelname ", fgYellow)),
  )
  when defined(httpx):
    result.instance = initSettings(Port(port), bindAddr=address)
  else:
    result.instance = newAsyncHttpServer()
  pointerServer = addr result
  addHandler(result.logger)


proc parseQuery*(query: string): owned(StringTableRef) =
  ## Parses query and retrieves JSON object
  runnableExamples:
    let
      query = "a=1000&b=8000&password=mystrongpass"
      parsedQuery = parseQuery(query)
    assert parsedQuery["a"] == "1000"
  result = newStringTable()
  for i in query.split('&'):
    let splitted = i.split('=')
    if splitted.len >= 2:
      result[splitted[0]] = splitted[1]


template start*(server: Server): untyped =
  ## The `start` template starts the given server and listens for incoming connections.
  ## Parameters:
  ## - `server`: A `Server` instance that needs to be started.
  ## 
  ## Returns:
  ## - `untyped`: This template does not return any value.
  when defined(debug):
    info fmt"Server started at http://{server.address}:{server.port}"
  when not declared(handleRequest):
    proc handleRequest(req: Request) {.async.} =
      discard
  when defined(httpx):
    run(handleRequest, `server`.instance)
  else:
    waitFor `server`.instance.serve(Port(`server`.port), handleRequest, `server`.address)


template answer*(
    req: Request,
    message: string,
    code: HttpCode = Http200,
    headers: HttpHeaders = newHttpHeaders([
      ("Content-Type", "text/plain; charset=utf-8")
    ])
) =
  ## Answers to the request
  ## 
  ## Arguments:
  ##   `req: Request`: An instance of the Request type, representing the request that we are responding to.
  ##   `message: string`: The message that we want to include in the response body.
  ##   `code: HttpCode = Http200`: The HTTP status code that we want to send in the response.
  ##                               This argument is optional, with a default value of Http200 (OK).
  when defined(httpx):
    var headersArr: seq[string] = @[]
    for key, value in headers.pairs():
      headersArr.add(key & ": " & value)
    req.send(code, message, headersArr.join("\r\n"))
  else:
    await req.respond(code, message, headers)


template answerJson*(req: Request, data: untyped, code: HttpCode = Http200,): untyped =
  ## Answers to request with json data
  answer(req, $(%*`data`), code, newHttpHeaders([("Content-Type", "application/json; charset=utf-8")]))


template answerHtml*(req: Request, data: string | TagRef, code: HttpCode = Http200,): untyped =
  ## Answers to request with HTML data
  when data is string:
    let d = data
  else:
    let d = $data
  answer(req, d, code, newHttpHeaders([("Content-Type", "text/html; charset=utf-8")]))


proc detectEndFunction(node: NimNode) {. compileTime .} =
  if node[^1].kind in [nnkCall, nnkCommand]:
    if node[^1][0].kind == nnkIdent and re"^(answer|echo)" in $node[^1][0]:
      return
    elif node[^1][0].kind == nnkDotExpr and ($node[^1][0][1]).toLower().startsWith("answer"):
      return
  node[^1] = newCall("answer", ident("req"), node[^1])


macro routes*(server: Server, body: untyped): untyped =
  ## You can create routes with this marco
  ## 
  ## #### Available Path Params
  ## - `int`: any integer.
  ## - `float`: any float number.
  ## - `word`: any word includes `re"\w+"`.
  ## - `string`: any string excludes `"/"`.
  ## - `path`: any float number includes `"/"`.
  ## - `regex`: any regex pattern excludes groups. Usage - `"/path{pattern:/yourRegex/}"`
  ## 
  ## #### Available Route Types
  ## - `"/path/with/{args:path}"`: Just string with route path. Matches any request method
  ## - `get "/path/{args:word}"`: Route with request method. Method can be`get`, `post`, `patch`, etc.
  ## - `notfound`: Route that matches when no other matched.
  ## - `middleware`: Always executes first.
  ## 
  ## #### In Route Types Scope:
  ## - `req`: Current request
  ## - `urlPath`: Current url path
  ## - `query`: Current url path queries
  ## - `wsConnections`: All websocket connections
  ## 
  ## #### Available Websocket Routing
  ## - `ws "/path/to/websockets/{args:word}`: Route with websockets
  ## - `wsConnect`: Calls on any websocket client was connected
  ## - `wsClosed`: Calls on any websocket client was disconnected
  ## - `wsMismatchProtocol`: Calls on mismatch protocol
  ## - `wsError`: Calls on any other ws error
  ## 
  ## #### In Websocket Scope:
  ## - `req`: Current request
  ## - `urlPath`: Current url path
  ## - `query`: Current url path queries
  ## - `wsClient`: Current websocket client
  ## - `wsConnections`: All websocket connections
  ## 
  runnableExamples:
    var myServer = newServer()
    myServer.routes:
      "/":
        "root"
      "/user{id:int}":
        fmt"hello, user {id}!"
      middleware:
        echo req
      notfound:
        "Oops! Not found!"
  var
    # Handle requests
    stmtList = newStmtList()
    ifStmt = newNimNode(nnkIfStmt)
    notFoundNode = newEmptyNode()
    wsNewConnection = newStmtList()
    wsClosedConnection = newStmtList()
    wsMismatchProtocol = newStmtList()
    wsError = newStmtList()
    procStmt = newProc(
      ident("handleRequest"),
      [newEmptyNode(), newIdentDefs(ident("req"), ident("Request"))],
      stmtList
    )
  when defined(httpx):
    var path = newNimNode(nnkBracketExpr).add(
      newCall("split", newCall("get", newCall("path", ident("req"))), newStrLitNode("?")),
      newIntLitNode(0)
    )
    let
      reqMethod = newCall("get", newDotExpr(ident("req"), ident("httpMethod")))
      reqMethodStringify = newCall("$", reqMethod)
      reqMethodStr = "req.httpMethod.get()"
      url = newStmtList(
        newLetStmt(ident("_val"), newCall("split", newCall("get", newCall("path", ident("req"))), newStrLitNode("?"))),
        newNimNode(nnkIfStmt).add(
          newNimNode(nnkElifBranch).add(
            newCall(">=", newCall("len", ident("_val")), newIntLitNode(2)),
            newNimNode(nnkBracketExpr).add(ident("_val"), newIntLitNode(1))
          ), newNimNode(nnkElse).add(
            newStrLitNode("")
          )
        )
      )
  else:
    var path = newDotExpr(newDotExpr(ident("req"), ident("url")), ident("path"))
    let
      reqMethod = newDotExpr(ident("req"), ident("reqMethod"))
      reqMethodStringify = newCall("$", reqMethod)
      reqMethodStr = "req.reqMethod"
      url = newDotExpr(newDotExpr(ident("req"), ident("url")), ident("query"))
  let directoryFromPath = newCall(
    "&",
    newStrLitNode("."),
    newCall("replace", path, newLit('/'), ident("DirSep"))
  )
  
  procStmt.addPragma(ident("async"))
  
  for statement in body:
    if statement.kind in [nnkCall, nnkCommand]:
      # "/...": statement list
      if statement[1].kind == nnkStmtList and statement[0].kind == nnkStrLit:
        detectEndFunction(statement[1])
        let exported = exportRouteArgs(path, statement[0], statement[1])
        if exported.len > 0:  # /my/path/with{custom:int}/{param:path}
          ifStmt.add(exported)
        else:  # /just-my-path
          ifStmt.add(newNimNode(nnkElifBranch).add(
            newCall("==", path, statement[0]), statement[1]
          ))
      # notfound: statement list
      elif statement[1].kind == nnkStmtList and statement[0].kind == nnkIdent:
        case ($statement[0]).toLower()
        of "wsconnect":
          wsNewConnection = statement[1]
        of "wsclosed":
          wsClosedConnection = statement[1]
        of "wsmismatchprotocol":
          wsMismatchProtocol = statement[1]
        of "wserror":
          wsError = statement[1]
        of "notfound":
          detectEndFunction(statement[1])
          notFoundNode = statement[1]
        of "middleware":
          detectEndFunction(statement[1])
          stmtList.insert(0, statement[1])
      # reqMethod "/...":
      #   ...
      elif statement[0].kind == nnkIdent and statement[1].kind == nnkStrLit:
        let name = ($statement[0]).toUpper()
        if name == "STATICDIR":
          ifStmt.insert(
            0, newNimNode(nnkElifBranch).add(
              newCall(
                "and",
                newCall(
                  "or",
                  newCall("startsWith", path, statement[1]),
                  newCall("startsWith", path, newStrLitNode("/" & $statement[1])),
                ), newCall(
                  "fileExists",
                  directoryFromPath
                )
              ),
              newStmtList(
                newLetStmt(
                  ident("file"),
                  newCall("openAsync", directoryFromPath)
                ),
                newLetStmt(
                  ident("content"),
                  newCall("await", newCall("readAll", ident("file")))
                ),
                newCall("answer", ident("req"), ident("content"))
              )
            )
          )
          continue
        let exported = exportRouteArgs(path, statement[1], statement[2])
        # Handle websockets
        if name == "WS":
          var
            insertWsList = newStmtList()
            wsDelStmt = newStmtList(
              newCall(
                "del",
                ident("wsConnections"),
                newCall("find", ident("wsConnections"), ident("wsClient")))
            )
          when defined(httpx):
            wsDelStmt.add(
              newCall("close", ident("wsClient"))
            )
          let wsStmtList = newStmtList(
            newLetStmt(ident("wsClient"), newCall("await", newCall("newWebSocket", ident("req")))),
            newCall("add", ident("wsConnections"), ident("wsClient")),
            newNimNode(nnkTryStmt).add(
              newStmtList(
                wsNewConnection,
                newNimNode(nnkWhileStmt).add(
                  newCall("==", newDotExpr(ident("wsClient"), ident("readyState")), ident("Open")),
                  newStmtList(
                    newLetStmt(ident("wsData"), newCall("await", newCall("receiveStrPacket", ident("wsClient")))),
                    insertWsList
                  )
                )
              ),
              newNimNode(nnkExceptBranch).add(
                ident("WebSocketClosedError"),
                when defined(debug):
                  newStmtList(
                    newCall(
                      "error", newStrLitNode("Socket closed")
                    ),
                    wsDelStmt,
                    wsClosedConnection
                  )
                elif wsClosedConnection.len == 0:
                  wsDelStmt
                else:
                  wsClosedConnection.add(wsDelStmt)
              ),
              newNimNode(nnkExceptBranch).add(
                ident("WebSocketProtocolMismatchError"),
                when defined(debug):
                  newStmtList(
                    newCall(
                      "error",
                      newCall("fmt", newStrLitNode("Socket tried to use an unknown protocol: {getCurrentExceptionMsg()}"))
                    ),
                    wsDelStmt,
                    wsMismatchProtocol
                  )
                elif wsMismatchProtocol.len == 0:
                  wsDelStmt
                else:
                  wsMismatchProtocol.add(wsDelStmt)
              ),
              newNimNode(nnkExceptBranch).add(
                ident("WebSocketError"),
                when defined(debug):
                  newStmtList(
                    newCall(
                      "error",
                      newCall("fmt", newStrLitNode("Unexpected socket error: {getCurrentExceptionMsg()}"))
                    ),
                    wsDelStmt,
                    wsError
                  )
                elif wsError.len == 0:
                  wsDelStmt
                else:
                  wsError.add(wsDelStmt)
              )
            )
          )
          if exported.len > 0:
            insertWsList.add(exported[1])
            exported[1].add(wsStmtList)
            ifStmt.add(exported)
          else:
            insertWsList.add(statement[2])
            ifStmt.add(newNimNode(nnkElifBranch).add(
              newCall("==", path, statement[1]),
              wsStmtList
            ))
          continue
        if exported.len > 0:  # /my/path/with{custom:int}/{param:path}
          exported[0] = newCall("and", exported[0], newCall("==", reqMethodStringify, newStrLitNode(name)))
          detectEndFunction(exported[1])
          ifStmt.add(exported)
        else:  # /just-my-path
          detectEndFunction(statement[2])
          ifStmt.add(newNimNode(nnkElifBranch).add(
            newCall(
              "and",
              newCall("==", path, statement[1]),
              newCall("==", reqMethodStringify, newStrLitNode(name))
            ),
            statement[2]
          ))

  # urlPath
  stmtList.insert(
    0, newNimNode(nnkLetSection).add(
      newIdentDefs(ident("urlPath"), newEmptyNode(), path),
      newIdentDefs(ident("reqMethod"), newEmptyNode(), reqMethod),
      newIdentDefs(ident("query"), newEmptyNode(), newCall("parseQuery", url)),
    )
  )
  
  when defined(debug):
    stmtList.add(newCall(
      "info",
      newCall("fmt", newStrLitNode("{" & reqMethodStr & "}::{urlPath}"))
    ))

  if ifStmt.len > 0:
    stmtList.add(ifStmt)
    # return 404
    if notFoundNode.kind == nnkEmpty:
      let elseStmtList = newStmtList()
      ifStmt.add(newNimNode(nnkElse).add(elseStmtList))
      when defined(debug):
        elseStmtList.add(
          newCall(
            "warn",
            newCall(
              "fgColored", 
              newCall("fmt", newStrLitNode("{urlPath} is not found.")), ident("fgYellow")
            )
          )
        )
      elseStmtList.add(
        newCall(ident("answer"), ident("req"), newStrLitNode("Not found"), ident("Http404"))
      )
    else:
      ifStmt.add(newNimNode(nnkElse).add(notFoundNode))
  else:
    # return 404
    if notFoundNode.kind == nnkEmpty:
      when defined(debug):
        stmtList.add(newCall(
          "warn",
          newCall(
            "fgColored",
            newCall("fmt", newStrLitNode("{urlPath} is not found.")), ident("fgYellow")
          )
        ))
      stmtList.add(
        newCall(ident("answer"), ident("req"), newStrLitNode("Not found"), ident("Http404"))
      )
    else:
      stmtList.add(notFoundNode)
  newStmtList(
    newNimNode(nnkVarSection).add(newIdentDefs(
      ident("wsConnections"),
      newNimNode(nnkBracketExpr).add(ident("seq"), ident("WebSocket")),
      newCall("@", newNimNode(nnkBracket)),
    )),
    procStmt
  )


macro initServer*(body: untyped): untyped =
  ## Shortcut for
  ## 
  ## .. code-block:: nim
  ##    proc main() {.gcsafe.} =
  ##      `body`
  ##    main()
  ## 
  result = newStmtList(
    newProc(
      ident("main"),
      [newEmptyNode()],
      body,
      nnkProcDef
    ),
    newCall("main")
  )
  result[0].addPragma(ident("gcsafe"))


macro serve*(address: string, port: int, body: untyped): untyped =
  ## Initializes a new server and start it. Shortcut for
  ## 
  ## .. code-block:: nim
  ##    proc main() =
  ##      var server = newServer(`address`, `port`)
  ##      server.routes:
  ##        `body`
  ##      server.start()
  ##    main()
  ## 
  result = newStmtList(
    newProc(
      ident("main"),
      [newEmptyNode()],
      newStmtList(
        newVarStmt(ident("server"), newCall("newServer", address, port)),
        newCall("routes", ident("server"), body),
        newCall("start", ident("server"))
      ),
      nnkProcDef
    ),
    newCall("main"),
  )
  result[0].addPragma(ident("gcsafe"))
