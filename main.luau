-- Carrega os modulos do GitHub e inicia o projeto pelo app.luau.
local ROOT = "https://raw.githubusercontent.com/Gamezim234/CreaturesOfSonaria/main/"
local cache={}
local function import(relative)
	if cache[relative]~=nil then return cache[relative] end
	local file=ROOT..relative
	local source=game:HttpGet(file)
	local chunk,err=loadstring(source,"@CreaturesOfSonaria/"..relative)
	assert(chunk,err)
	local result=chunk()
	cache[relative]=result
	return result
end
return import("app.luau")(import)
