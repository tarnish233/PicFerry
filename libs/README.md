# Native libraries

`libminipng-arm64.a` is the Apple Silicon slice extracted from the bundled
`libminipng.framework` static archive. Its debug/module symbols are stripped so
Release links do not reference the original producer's local module cache.

Rebuild it on macOS with:

```sh
lipo libminipng.framework/Versions/A/libminipng \
  -thin arm64 \
  -output libminipng-arm64.a
strip -S -x libminipng-arm64.a
```

The upstream license remains at
`libminipng.framework/Versions/A/Resources/LICENSE`.
