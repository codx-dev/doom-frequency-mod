lua_modules := "lua_modules"

install:
  luarocks install --tree {{lua_modules}} busted 2>/dev/null || true

test:
  eval $(luarocks --tree {{lua_modules}} path) && \
    {{lua_modules}}/bin/busted \
      --pattern='_spec' \
      --lpath='Contents/mods/?.lua' \
      tests/
