-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

-- @type LazySpec
return {
	"AstroNvim/astrocommunity",

	-- Packs
	{ import = "astrocommunity.pack.ansible" },
	{ import = "astrocommunity.pack.bash" },
	{ import = "astrocommunity.pack.cmake" },
	{ import = "astrocommunity.pack.cpp" },
	{ import = "astrocommunity.pack.docker" },
	{ import = "astrocommunity.pack.go" },
	{ import = "astrocommunity.pack.helm" },
	{ import = "astrocommunity.pack.html-css" },
	{ import = "astrocommunity.pack.java" },
	{ import = "astrocommunity.pack.json" },
	{ import = "astrocommunity.pack.lua" },
	{ import = "astrocommunity.pack.markdown" },
	{ import = "astrocommunity.pack.python-ruff" },
	{ import = "astrocommunity.pack.rust" },
	{ import = "astrocommunity.pack.terraform" },
	{ import = "astrocommunity.pack.toml" },
	{ import = "astrocommunity.pack.vue" },
	{ import = "astrocommunity.pack.xml" },
	{ import = "astrocommunity.pack.yaml" },

	-- Markdown and LaTex
	{ import = "astrocommunity.markdown-and-latex.vimtex" },

	-- Recipes
	{ import = "astrocommunity.recipes.heirline-mode-text-statusline" },
}
