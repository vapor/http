# Engine

![Swift](http://img.shields.io/badge/swift-3.0-brightgreen.svg)
[![Build Status](https://travis-ci.org/vapor/core.svg?branch=master)](https://travis-ci.org/vapor/engine)
[![CircleCI](https://circleci.com/gh/vapor/core.svg?style=shield)](https://circleci.com/gh/vapor/engine)
[![Code Coverage](https://codecov.io/gh/vapor/core/branch/master/graph/badge.svg)](https://codecov.io/gh/vapor/engine)
[![Codebeat](https://codebeat.co/badges/a793ad97-47e3-40d9-82cf-2aafc516ef4e)](https://codebeat.co/projects/github-com-vapor-engine)
[![Slack Status](http://vapor.team/badge.svg)](http://vapor.team)

Engine is a collection of low level transport protocols implemented in pure Swift intended for use in server side and client side applications. It is used as the core transport layer in [Vapor](https://github.com/qutheory/github).

## 🐧 Linux Ready

Runs everywhere Swift does.

## 📦 Examples

Check out the HTTP, SMTP, and WebSockets examples in `Sources/`. You can clone this repository and run them on your computer.

## 📘 Overview

- HTTP (client/server)
- WebSocket (client/server)
- SMTP (client)

## 🏛 Architecture

### HTTP.Server

The HTTPServer is responsible for listening and accepting remote connections, then relaying requests and responses between the received connection and the responder.

![](https://cloud.githubusercontent.com/assets/1342803/20292292/619546d4-aaba-11e6-91cb-867b5d893e71.png)


### HTTP.Client

The HTTPClient is responsible for establishing remote connections and relaying requests and responses between the remote connection and the caller.

![](https://cloud.githubusercontent.com/assets/1342803/20292280/55afda46-aaba-11e6-8aef-7b17e703edef.png)


## 📖 Documentation

Visit the Vapor web framework's [documentation](http://docs.vapor.codes) for instructions on how to use this package.

## 💧 Community

Join the welcoming community of fellow Vapor developers in [slack](http://vapor.team).

## 🔧 Compatibility

This package has been tested on macOS and Ubuntu.
