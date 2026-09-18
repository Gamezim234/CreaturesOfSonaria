-- Loader: baixa modulos do GitHub e inicia app.luau
local ROOT = "https://raw.githubusercontent.com/Gamezim234/CreaturesOfSonaria/main/"
local cache = {}

local function import(relative)
	if cache[relative] ~= nil then
		return cache[relative]
	end
	-- cache-bust para nao pegar raw antigo do GitHub/CDN
	local url = ROOT .. relative .. "?t=" .. tostring(tick())
	local okGet, source = pcall(function()
		return game:HttpGet(url)
	end)
	if not okGet or type(source) ~= "string" or source == "" then
		error("[CoS] HttpGet falhou: " .. relative .. " | " .. tostring(source))
	end
	if string.find(source, "404") == 1 or string.find(source, "Not Found") then
		error("[CoS] Arquivo nao encontrado no GitHub: " .. relative)
	end
	local chunk, err = loadstring(source, "@CreaturesOfSonaria/" .. relative)
	if not chunk then
		error("[CoS] loadstring falhou em " .. relative .. ":\n" .. tostring(err))
	end
	local okRun, result = pcall(chunk)
	if not okRun then
		error("[CoS] Erro ao executar " .. relative .. ":\n" .. tostring(result))
	end
	cache[relative] = result
	return result
end

print("[CoS] carregando app.luau...")
local ok, err = pcall(function()
	local app = import("app.luau")
	if type(app) ~= "function" then
		error("app.luau nao retornou function, got " .. type(app))
	end
	app(import)
end)

if not ok then
	warn("[CoS] FALHA AO INICIAR:\n" .. tostring(err))
else
	print("[CoS] init ok")
end
