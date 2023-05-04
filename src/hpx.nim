import
  happyx,
  strutils,
  terminal,
  regex,
  cligen,
  os

import illwill except fgBlue, fgGreen, fgMagenta, fgRed, fgWhite, fgYellow, bgBlue, bgGreen, bgMagenta, bgRed, bgWhite, bgYellow


const VERSION = "0.7.1"


proc ctrlC {. noconv .} =
  illwillDeinit()
  quit(QuitSuccess)

illwillInit(fullscreen=true)
setControlCHook(ctrlC)


proc buildCommand(): int =
  styledEcho "Builded!"
  QuitSuccess


proc createCommand(): int =
  var
    projectName: string
    selected: int = 0
  let projectTypes = ["SSG", "SPA"]
  styledEcho "New ", fgBlue, "HappyX", fgWhite, " project ..."
  # Get project name
  styledWrite stdout, fgYellow, align("Project name: ", 14)
  projectName = readLine(stdin)
  while projectName.len < 1 or projectName.contains(re"[,!\\/':@~`]"):
    styledEcho fgRed, "Invalid name! It doesn't contains one of these symbols: , ! \\ / ' : @ ~ `"
    styledWrite stdout, fgYellow, align("Project name: ", 14)
    projectName = readLine(stdin)

  styledEcho "Ok, now, choose project type ", fgYellow, "(via arrow keys)"
  var
    choosen = false
    needRefresh = true
  while not choosen:
    if needRefresh:
      needRefresh = false
      for i, val in projectTypes:
        if i == selected:
          styledEcho fgGreen, "> ", val
        else:
          styledEcho fgYellow, "  ", val
    case getKey()
    of Key.Up, Key.ShiftH:
      if selected > 0:
        needRefresh = true
        dec selected
    of Key.Down, Key.ShiftP:
      if selected < projectTypes.len-1:
        needRefresh = true
        inc selected
    of Key.Enter:
      choosen = true
      break
    else:
      discard
    if needRefresh:
      for i in projectTypes:
        eraseLine(stdout)
        cursorUp(stdout)
  
  styledEcho "You choose:"
  styledEcho "Project name is ", fgMagenta, projectName
  styledEcho fgMagenta, projectTypes[selected], fgWhite, " project type"
  styledEcho "Continue? ", fgYellow, "[Y/N]"
  let isContinue = ($readChar(stdin)).toLower()

  if isContinue == "y":
    styledEcho "Initializing project ..."
    createDir(projectName)
    createDir(projectName / "src")
    createDir(projectName / "public")
    var f = open(projectName / ".gitignore", fmWrite)
    f.write("# Nimcache\nnimcache/\ncache/\n\n# Garbage\n*.exe\n*.log\n*.lg")
    f.close()
    f = open(projectName / "README.md", fmWrite)
    f.write(fmt"# {projectName}\n\n{projectTypes[selected]} project written in Nim with HappyX ❤")
    f.close()

    case selected
    of 0:
      # SSG
      f = open(projectName / "src" / "main.nim", fmWrite)
      f.write("import happyx\n\nserve(\"127.0.0.1\", 5000):\n  get \"/\":\n    \"Hello, world!\"\n")
      f.close()
    of 1:
      # SPA
      createDir(projectName / "src" / "components")
      f = open(projectName / "src" / "main.nim", fmWrite)
      f.write("import happyx\n\n\nvar app = registerApp()\n\napp.routes:\n  \"/\":\n    component HelloWorld\n\napp.start()\n")
      f.close()
      f = open(projectName / "src" / "components" / "hello_world.nim", fmWrite)
      f.write("import happyx\n\n\ncomponent HelloWorld:\n  `template`:\n    \"Hello, world!\"\n\n`script`:\n    echo \"Start coding!\"\n")
      f.close()
    else:
      discard
    styledEcho fgGreen, "Successfully created!"
    return QuitSuccess
  else:
    return createCommand()


proc devCommand(host: string = "127.0.0.1", port: int = 5000): int =
  styledEcho "Starting serve at ", fgGreen, "http://", host, ":", $port, fgWhite, "!"
  QuitSuccess


proc mainCommand(version = false): int =
  if version:
    styledEcho "HappyX ", fgGreen, VERSION
  else:
    styledEcho fgYellow, "[Warning] ", fgWhite, "no arguments"
  QuitSuccess


when isMainModule:
  dispatchMultiGen(
    [buildCommand, cmdName = "build"],
    [devCommand, cmdName = "dev"],
    [createCommand, cmdName = "create"],
    [
      mainCommand,
      short = {"version": 'v'}
    ]
  )
  let
    pars = commandLineParams()
    subcmd =
      if pars.len > 0 and not pars[0].startsWith("-"):
        pars[0]
      else:
        ""
  case subcmd
  of "build":
    quit(dispatchbuild(cmdline = pars[1..^1]))
  of "dev":
    quit(dispatchdev(cmdline = pars[1..^1]))
  of "create":
    quit(dispatchcreate(cmdline = pars[1..^1]))
  of "help":
    let
      subcmdHelp =
        if pars.len > 1 and not pars[1].startsWith("-"):
          pars[1]
        else:
          ""
      use = "hpx $command $args\n$doc\nOptions:\n$options"
    case subcmdHelp:
    of "":
      styledEcho fgBlue, center("# ---=== HappyX CLI ===--- #", 28)
      styledEcho fgGreen, align("v" & VERSION, 28)
      styledEcho(
        "\nCLI for ", fgGreen, "creating", fgWhite, ", ",
        fgGreen, "serving", fgWhite, " and ", fgGreen, "building",
        fgWhite, " HappyX projects\n"
      )
      styledEcho "Usage:"
      styledEcho fgMagenta, "hpx ", fgBlue, "build|dev|create|help ", fgYellow, "[subcommand-args]"
    of "build":
      styledEcho fgBlue, "HappyX", fgMagenta, " build ", fgWhite, " command builds existing HappyX project."
      styledEcho "Usage:\n"
      styledEcho fgMagenta, "hpx build"
    of "dev":
      styledEcho fgBlue, "HappyX", fgMagenta, " dev ", fgWhite, "command creates a new HappyX project."
      styledEcho "\nUsage:"
      styledEcho fgMagenta, "hpx dev\n"
      styledEcho "Optional arguments:"
      styledEcho align("host", 8), "|h - change address (default is 127.0.0.1)"
      styledEcho align("port", 8), "|p - change port (default is 5000)"
    of "create":
      styledEcho fgBlue, "HappyX", fgMagenta, " create ", fgWhite, "command creates a new HappyX project."
      styledEcho "\nUsage:"
      styledEcho fgMagenta, "hpx create"
    else:
      styledEcho fgRed, "Unknown subcommand: ", fgWhite, subcmdHelp
  of "":
    quit(dispatchmainCommand(cmdline = pars[0..^1]))
  else:
    styledEcho fgRed, "Unknown subcommand: ", fgWhite, subcmd
    quit(QuitFailure)