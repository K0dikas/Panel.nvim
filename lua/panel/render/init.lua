---@tag panel-render()
---@brief [[
--- Notification buffer rendering
---
--- Custom rendering can be provided by both the user config in the setup or on
--- an individual notification using the `render` key.
--- The key can either be the name of a built-in renderer or a custom function.
---
--- Built-in renderers:
--- - `"default"`
--- - `"minimal"`
--- - `"simple"`
---
--- Custom functions should accept a buffer, a notification record and a highlights table
---
--- <pre>
--- >
---     render: fun(buf: integer, notification: panel.Record, highlights: panel.Highlights, config)
--- </pre>
--- You should use the provided highlight groups to take advantage of opacity
--- changes as they will be updated as the notification is animated
---@brief ]]

---@class panel.Highlights
---@field title string
---@field icon string
---@field border string
---@field body string
local M = {}

setmetatable(M, {
	__index = function(_, key)
		return require("panel.render." .. key)
	end,
})

return M
