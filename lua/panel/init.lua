---@brief [[
---A fancy, configurable notification manager for NeoVim
---@brief ]]

---@tag nvim-panel

local config = require("panel.config")
local stages = require("panel.stages")
local Notification = require("panel.service.notification")
local WindowAnimator = require("panel.windows")
local NotificationService = require("panel.service")
local NotificationBuf = require("panel.service.buffer")
local stage_util = require("panel.stages.util")

---@type Notification[]
local notifications = {}

local panel = {}

local global_instance, global_config

---Configure nvim-panel
---<pre>
---    See: ~
---        |panel.Config|
---</pre>
---@param user_config panel.Config | nil
---@eval { ['description'] = require('panel.config')._format_default() }
---@see panel-render
function panel.setup(user_config)
	global_instance, global_config = panel.instance(user_config)
	local has_telescope = (vim.fn.exists("g:loaded_telescope") == 1)
	if has_telescope then
		require("telescope").load_extension("panel")
	end
	vim.cmd([[command! Notifications :lua require("panel")._print_history()<CR>]])
end

function panel._config()
	return config.setup(global_config)
end

---@class panel.Options @Options for an individual notification
---@field title string
---@field icon string
---@field timeout number | boolean: Time to show notification in milliseconds, set to false to disable timeout.
---@field on_open function: Callback for when window opens, receives window as argument.
---@field on_close function: Callback for when window closes, receives window as argument.
---@field keep function: Function to keep the notification window open after timeout, should return boolean.
---@field render function: Function to render a notification buffer.
---@field replace integer | panel.Record: Notification record or the record `id` field. Replace an existing notification if still open. All arguments not given are inherited from the replaced notification including message and level.
---@field hide_from_history boolean: Hide this notification from the history
---@field animate boolean: If false, the window will jump to the timed stage. Intended for use in blocking events (e.g. vim.fn.input)

---@class NotificationEvents @Async events for a notification
---@field open function: Resolves when notification is opened
---@field close function: Resolved when notification is closed

---@class panel.Record @Record of a previously sent notification
---@field id integer
---@field message string[]: Lines of the message
---@field level string|integer: Log level. See vim.log.levels
---@field title string[]: Left and right sections of the title
---@field icon string: Icon used for notification
---@field time number: Time of message, as returned by `vim.fn.localtime()`
---@field render function: Function to render notification buffer

---@class panel.AsyncRecord : panel.Record
---@field events NotificationEvents

---Display a notification.
---
---You can call the module directly rather than using this:
---<pre>
--->
---  require("panel")(message, level, opts)
---</pre>
---@param message string | string[]: Notification message
---@param level string | number: Log level. See vim.log.levels
---@param opts panel.Options: Notification options
---@return panel.Record
function panel.panel(message, level, opts)
	if not global_instance then
		panel.setup()
	end
	return global_instance.panel(message, level, opts)
end

---Display a notification asynchronously
---
---This uses plenary's async library, allowing a cleaner interface for
---open/close events. You must call this function within an async context.
---
---The `on_close` and `on_open` options are not used.
---
---@param message string | string[]: Notification message
---@param level string | number: Log level. See vim.log.levels
---@param opts panel.Options: Notification options
---@return panel.AsyncRecord
function panel.async(message, level, opts)
	if not global_instance then
		panel.setup()
	end
	return global_instance.async(message, level, opts)
end

---Get records of all previous notifications
---
--- You can use the `:Notifications` command to display a log of previous notifications
---@param args table
---@field include_hidden boolean: Include notifications hidden from history
---@return panel.Record[]
function panel.history(args)
	if not global_instance then
		panel.setup()
	end
	return global_instance.history(args)
end

---Dismiss all notification windows currently displayed
---@param opts table
---@field pending boolean: Clear pending notifications
---@field silent boolean: Suppress notification that pending notifications were dismissed.
function panel.dismiss(opts)
	if not global_instance then
		panel.setup()
	end
	return global_instance.dismiss(opts)
end

---@class panel.OpenedBuffer
---@field buffer integer: Created buffer number
---@field height integer: Height of the buffer content including extmarks
---@field width integer: width of the buffer content including extmarks
---@field highlights table<string, string>: Highlights used for the buffer contents

---Open a notification in a new buffer
---@param notif_id integer | panel.Record
---@param opts table
---@field buffer integer: Use this buffer, instead of creating a new one
---@field max_width integer: Render message to this width (used to limit window decoration sizes)
---@return panel.OpenedBuffer
function panel.open(notif_id, opts)
	if not global_instance then
		panel.setup()
	end
	return global_instance.open(notif_id, opts)
end

---Number of notifications currently waiting to be displayed
---@return table<integer, integer>
function panel.pending()
	if not global_instance then
		panel.setup()
	end
	return global_instance.pending()
end

function panel._print_history()
	if not global_instance then
		panel.setup()
	end
	for _, notif in ipairs(global_instance.history()) do
		vim.api.nvim_echo({
			{ vim.fn.strftime("%FT%T", notif.time), "NotifyLogTime" },
			{ " ", "MsgArea" },
			{ notif.title[1], "NotifyLogTitle" },
			{ #notif.title[1] > 0 and " " or "", "MsgArea" },
			{ notif.icon, "Notify" .. notif.level .. "Title" },
			{ " ", "MsgArea" },
			{ notif.level, "Notify" .. notif.level .. "Title" },
			{ " ", "MsgArea" },
			{ table.concat(notif.message, "\n"), "MsgArea" },
		}, false, {})
	end
end

---Configure an instance of nvim-panel.
---You can use this to manage a separate instance of nvim-panel with completely different configuration.
---The returned instance will have the same functions as the panel module.
---@param user_config panel.Config
---@param inherit boolean: Inherit the global configuration, default true
function panel.instance(user_config, inherit)
	user_config = user_config or {}
	if inherit ~= false and global_config then
		user_config = vim.tbl_deep_extend("force", global_config, user_config)
	end

	local instance_config = config.setup(user_config)

	local animator_stages = instance_config.stages()
	local direction = instance_config.top_down() and stage_util.DIRECTION.TOP_DOWN
	or stage_util.DIRECTION.BOTTOM_UP

	animator_stages = type(animator_stages) == "string" and stages[animator_stages](direction)
	or animator_stages
	local animator = WindowAnimator(animator_stages, instance_config)
	local service = NotificationService(instance_config, animator)

	local instance = {}

	local function get_render(render)
		if type(render) == "function" then
			return render
		end
		return require("panel.render")[render]
	end

	function instance.panel(message, level, opts)
		opts = opts or {}
		if opts.replace then
			if type(opts.replace) == "table" then
				opts.replace = opts.replace.id
			end
			local existing = notifications[opts.replace]
			if not existing then
				vim.panel("Invalid notification to replace", "error", { title = "nvim-panel" })
				return
			end
			local notif_keys = {
				"title",
				"icon",
				"timeout",
				"keep",
				"on_open",
				"on_close",
				"render",
				"hide_from_history",
				"animate",
			}
			message = message or existing.message
			level = level or existing.level
			for _, key in ipairs(notif_keys) do
				opts[key] = opts[key] or existing[key]
			end
		end
		opts.render = get_render(opts.render or instance_config.render())
		local id = #notifications + 1
		local notification = Notification(id, message, level, opts, instance_config)
		table.insert(notifications, notification)
		local level_num = vim.log.levels[notification.level]
		if opts.replace then
			service:replace(opts.replace, notification)
		elseif not level_num or level_num >= instance_config.level() then
			service:push(notification)
		end
		return {
			id = id,
		}
	end

	---@param notif_id integer | panel.Record
	---@param opts table
	function instance.open(notif_id, opts)
		opts = opts or {}
		if type(notif_id) == "table" then
			notif_id = notif_id.id
		end
		local notif = notifications[notif_id]
		if not notif then
			vim.panel(
			"Invalid notification id: " .. notif_id,
			vim.log.levels.WARN,
			{ title = "nvim-panel" }
			)
			return
		end
		local buf = opts.buffer or vim.api.nvim_create_buf(false, true)
		local notif_buf =
		NotificationBuf(buf, notif, vim.tbl_extend("keep", opts, { config = instance_config }))
		notif_buf:render()
		return {
			buffer = buf,
			height = notif_buf:height(),
			width = notif_buf:width(),
			highlights = {
				body = notif_buf.highlights.body,
				border = notif_buf.highlights.border,
				title = notif_buf.highlights.title,
				icon = notif_buf.highlights.icon,
			},
		}
	end

	function instance.async(message, level, opts)
		opts = opts or {}
		local async = require("plenary.async")
		local send_close, wait_close = async.control.channel.oneshot()
		opts.on_close = send_close

		local send_open, wait_open = async.control.channel.oneshot()
		opts.on_open = send_open

		async.util.scheduler()
		local record = instance.panel(message, level, opts)
		return vim.tbl_extend("error", record, {
			events = {
				open = wait_open,
				close = wait_close,
			},
		})
	end

	function instance.history(args)
		args = args or {}
		local records = {}
		for _, notif in ipairs(notifications) do
			if not notif.hide_from_history or args.include_hidden then
				records[#records + 1] = notif:record()
			end
		end
		return records
	end

	function instance.dismiss(opts)
		if service then
			service:dismiss(opts or {})
		end
	end

	function instance.pending()
		return service and service:pending() or {}
	end

	setmetatable(instance, {
		__call = function(_, m, l, o)
			if vim.in_fast_event() then
				vim.schedule(function()
					instance.panel(m, l, o)
				end)
			else
				return instance.panel(m, l, o)
			end
		end,
	})
	return instance, instance_config.merged()
end

setmetatable(panel, {
	__call = function(_, m, l, o)
		if vim.in_fast_event() then
			vim.schedule(function()
				panel.panel(m, l, o)
			end)
		else
			return panel.panel(m, l, o)
		end
	end,
})

return panel
