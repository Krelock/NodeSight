# Tests

The tests run outside the game with [busted](https://lunarmodules.github.io/busted/) on Lua 5.1, the Lua version of the game. They are for development only: `spec/` and `.busted` do not belong in the release zip.

Install busted once with `luarocks --lua-version=5.1 install busted`, or on Debian and Ubuntu with `apt install lua-busted`. Run `busted` from the addon folder.

`spec/helpers/wow.lua` loads the addon's files in .toc order with a stubbed game API. Every load gets its own environment, so stubs and saved variables never leak from one test into the next.
