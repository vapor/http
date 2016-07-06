# Contributing to OSS

If you've never contributed to an OSS project before, here's a <a href="https://akrabat.com/the-beginners-guide-to-contributing-to-a-github-project/">great guide</a> to get you started.

# Building Vapor

The Engine master branch is often ahead of our release, so the tooling can be a bit different.

## Swift Version

Check the `.swift-version` file for the version being used for current development

## Xcode

In the terminal, `cd` into the repo and build the Xcode Project.

#### Vapor CLI

```Swift
cd path/to/my/project
vapor xcode
```

#### Native SPM

```Swift
cd path/to/my/project
swift package generate-xcodeproj
open *.xcodeproj
```

## EngineExample

We have a `EngineExample` target inside of the project that can be used for live testing. It is imperative that this be left as server in shipping, this is how we provide the heroku button.

## Tests

Pull requests without adequate testing may be delayed. Please add tests alongside your pull requests.

## Slack

Join us in the #development channel in slack, for questions and discussions.
