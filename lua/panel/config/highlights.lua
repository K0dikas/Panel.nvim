local M = {}

function M.setup()
	vim.cmd([[
	hi default link PanelBackground Normal
	hi default PanelERRORBorder guifg=#8A1F1F
	hi default PanelWARNBorder guifg=#79491D
	hi default PanelINFOBorder guifg=#076678
	hi default PanelDEBUGBorder guifg=#8B8B8B
	hi default PanelTRACEBorder guifg=#4F3552
	hi default PanelERRORIcon guifg=#F70067
	hi default PanelWARNIcon guifg=#F79000
	hi default PanelINFOIcon guifg=#28607c
	hi default PanelDEBUGIcon guifg=#8B8B8B
	hi default PanelTRACEIcon guifg=#D484FF
	hi default PanelERRORTitle  guifg=#F70067
	hi default PanelWARNTitle guifg=#F79000
	hi default PanelINFOTitle guifg=#fb4934
	hi default PanelDEBUGTitle  guifg=#8B8B8B
	hi default PanelTRACETitle  guifg=#D484FF
	hi default link PanelERRORBody Normal
	hi default link PanelWARNBody Normal
	hi default link PanelINFOBody Normal
	hi default link PanelDEBUGBody Normal
	hi default link PanelTRACEBody Normal

	hi default link PanelLogTime Comment
	hi default link PanelLogTitle Special
	]])
end

M.setup()

vim.cmd([[
augroup NvimPanelRefreshHighlights
autocmd!
autocmd ColorScheme * lua require('panel.config.highlights').setup()
augroup END
]])

return M
