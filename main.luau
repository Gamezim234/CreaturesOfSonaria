-- Carrega os arquivos locais e inicia o projeto pelo app.luau.
local ROOT = [[C:/Users/rosap/OneDrive/Área de Trabalho/scripts/CreaturesOfSonaria/]]
local cache={}
local function import(relative)
	if cache[relative]~=nil then return cache[relative] end
	local file=ROOT..relative
	local source=readfile(file)
	local chunk,err=loadstring(source,"@CreaturesOfSonaria/"..relative)
	assert(chunk,err)
	local result=chunk()
	cache[relative]=result
	return result
end
return import("app.luau")(import)
