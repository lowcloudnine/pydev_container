-- AstroCommunity: import any community modules here

---@type LazySpec
return {
	"AstroNvim/astrocommunity",

	-- AI
	{ import = "astrocommunity.ai.codex-nvim" },

	-- Docker
	{ import = "astrocommunity.docker.lazydocker" },

	-- Packs
	{ import = "astrocommunity.pack.ansible" },
	{ import = "astrocommunity.pack.bash" },
	{ import = "astrocommunity.pack.cmake" },
	{ import = "astrocommunity.pack.cpp" },
	{ import = "astrocommunity.pack.docker" },
	{ import = "astrocommunity.pack.go" },
	{ import = "astrocommunity.pack.helm" },
	{ import = "astrocommunity.pack.html-css" },
	{ import = "astrocommunity.pack.json" },
	{ import = "astrocommunity.pack.lua" },
	{ import = "astrocommunity.pack.markdown" },
	{ import = "astrocommunity.pack.rust" },
	{ import = "astrocommunity.pack.terraform" },
	{ import = "astrocommunity.pack.toml" },
	{ import = "astrocommunity.pack.vue" },
	{ import = "astrocommunity.pack.xml" },
	{ import = "astrocommunity.pack.yaml" },

	-- Base pack with basedpyright and ruff
	{ import = "astrocommunity.pack.python.base" },
	{ import = "astrocommunity.pack.python.basedpyright" },
	{ import = "astrocommunity.pack.python.ruff" },
	{ import = "astrocommunity.pack.python.ty" },

	-- Markdown and LaTex
	{ import = "astrocommunity.markdown-and-latex.vimtex" },

	-- Recipes
	{ import = "astrocommunity.recipes.heirline-mode-text-statusline" },

	-- Tools are provisioned and verified during the image build. Do not try to
	-- download missing tools whenever Neovim starts in an offline container.
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		opts = { run_on_start = false, auto_update = false },
	},
}
