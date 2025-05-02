# TeleGleam

This a [TUI](https://en.wikipedia.org/wiki/Text-based_user_interface) that uses the [Telegram Bot API](https://core.telegram.org/bots/api) to make posting things to [Telegram](https://telegram.org) easier (sometimes).

## The Motivation

The main thing I wanted to be able to do was to create galleries in Telegram channels and the photos and videos would have captions based on metadate that was already in their files via [exif metadata](https://en.wikipedia.org/wiki/Exif).

## Development

If you want to work on TeleGleam it's written in the [Gleam programming language](https://gleam-lang.org/) and then compiled to JavaScript.

The tooling is pretty straight forward but to make things even easier I have things setup with [devbox](https://www.jetify.com/devbox). You can see the tooling dependencies in `devbox.json`.

```sh
# startup the shell
devbox shell

# build
devbox run build

# run
node telegleam.js --help
```

## Dependencies

In addition to the dependencies listed in `gleam.toml`, TeleGleam also depends on the following projects but they were either not avalible as packages and/or I had to modify them a bit so the code has been "vendored" into this code base (but not in an organized way):

- [glexif](https://github.com/justinrassier/glexif) for reading EXIF metadata from images and videos. I had to update a couple of things and make it compatiable with the JavaScript target.
- [teashop](https://github.com/erikareads/teashop) is a framework for building TUIs.

Hopefully, someday these dependencies will be avalible as packages and the vendored code can be removed. I really appreciate the work and thoughtfullness that has gone into these projects and that they were "avalible" even though they were not packages.
