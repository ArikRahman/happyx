<div align="center">

![Happyx](https://user-images.githubusercontent.com/49402667/228402522-6dd72d4b-c21c-4acf-b1e2-8318b6e809da.png)
### Macro-oriented asynchronous web-framework written in Nim with ♥

![Nim language](https://img.shields.io/badge/>=1.6.12-1b1e2b?style=for-the-badge&logo=nim&logoColor=f1fa8c&label=Nim&labelColor=2b2e3b)

[![wakatime](https://wakatime.com/badge/user/eaf11f95-5e2a-4b60-ae6a-38cd01ed317b/project/bbd13748-36e6-4383-ac40-9c4e72c060d1.svg?style=for-the-badge)](https://wakatime.com/badge/user/eaf11f95-5e2a-4b60-ae6a-38cd01ed317b/project/bbd13748-36e6-4383-ac40-9c4e72c060d1)

[![Testing](https://github.com/HapticX/happyx/actions/workflows/tests.yml/badge.svg?style=for-the-badge)](https://github.com/HapticX/happyx/actions/workflows/tests.yml)

</div>


# Why HappyX? 💁‍♀️
> HappyX is macro-oriented asynchronous web framework.

In HappyX you can write `single page`, `static site generation` and `server side rendering` applications 💡

You can writing Rest API with HappyX also 🔌

HappyX is very simple to use. Keep it mind 🙂

## Features ⚡
- Support `asynchttpserver` as default HTTP server.
- Support `httpx` via `-d:httpx` and `microhttpserver` via `-d:micro` as alternative HTTP servers.
- Support `SPA` on `JS` backend and `SSG` on other backends.
- Building HTML with `buildHtml` macro.
- Routing `SPA`/`SSG` with `routes` marco.
- Powerful path params for routing.
- Logging with `-d:debug`.
- CLI tool for `creating`, `serving` and `building` your projects.
- Hot code reloading (now only for `SPA` projects).

## Why not Jester? 🤔
Jester doesn't provides some features that provides Happyx.

# Get Started 👨‍🔬

## Installing 📥
### Via Nimble
```bash
nimble install happyx
```
### Via GitHub
```bash
nimble install https://github.com/HapticX/happyx
```

## Usage ▶
### SSG
```bash
hpx create --name ssg_project --kind SSG
cd ssg_project
```

Main script will be able in `/ssg_project/src/main.nim`

#### Run 💻

|           Default        |             Httpx                 |       microasynchttpserver        |
|           :---:          |             :---:                 |             :---:                 |
| `nim c -r -d:debug main` | `nim c -r -d:debug -d:httpx main` | `nim c -r -d:debug -d:micro main` |

### SPA
```bash
hpx create --name spa_project --kind SPA --path-params
cd spa_project
```

Main script will be able in `/spa_project/src/main.nim`

#### Run 💻
Just run this command and see magic ✨
```bash
hpx dev --reload
```


# Contributing 🌀
See [Contributing.md](https://github.com/HapticX/happyx/blob/master/.github/CONTRIBUTING.md) for more information
