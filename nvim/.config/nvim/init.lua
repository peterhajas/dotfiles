-- Remove ./?.lua from package.path so require() won't load from cwd
package.path = package.path:gsub("%.[/\\]%?%.lua;?", "")

vim.loader.enable()

require("phajas")
