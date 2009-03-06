do
    local luatextrapath = kpse.find_file("luatextra.lua")
    if luatextrapath then
        if luatextrapath:sub(1,2) == "./" then
            luatextrapath = luatextrapath:sub(3)
        end
        texio.write(' ('..luatextrapath) 
    end
end

luatextra = {}

module("luatextra", package.seeall)

luatextra.modules = luatextra.modules or {}

luatextra.modules['luatextra'] = {
    version     = 0.9,
    name        = "luatextra",
    date        = "2009/02/26",
    description = "Low level functions for LuaTeX basic usage",
    author      = "Elie Roux",
    copyright   = "Elie Roux, 2009",
    license     = "CC0",
}

local format = string.format

luatextra.internal_warning_spaces = "                   "

function luatextra.internal_warning(msg)
    if not msg then return end
    texio.write_nl(format("\nLuaTeXtra Warning: %s\n\n", msg))
end

luatextra.internal_error_spaces = "                 "

function luatextra.internal_error(msg)
    if not msg then return end
    tex.sprint(format("\\immediate\\write16{}\\errmessage{LuaTeXtra error: %s^^J^^J}", msg))
end

function luatextra.module_error(package, msg, helpmsg)
    if not package or not msg then
        return
    end
    if helpmsg then
        tex.sprint(format("\\errhelp{%s}", helpmsg))
    end
    tex.sprint(format("\\luaModuleError{%s}{%s}", package, msg))
end

function luatextra.module_warning(modulename, msg)
    if not modulename or not msg then
        return
    end
    texio.write_nl(format("\nModule %s Warning: %s\n\n", modulename, msg))
end

function luatextra.module_log(modulename, msg)
    if not modulename or not msg then
        return
    end
    texio.write_nl('log', format("%s: %s", modulename, msg))
end

function luatextra.module_info(modulename, msg)
    if not modulename or not msg then
        return
    end
    texio.write_nl(format("%s: %s\n", modulename, msg))
end

function luatextra.find_module_file(name)
    if string.sub(name, -4) ~= '.lua' then
        name = name..'.lua'
    end
    path = kpse.find_file(name)
    return path, name
end

function luatextra.use_module(name)
    if not name or luatextra.modules[name] then
        return
    end
    local path, filename = luatextra.find_module_file(name)
    if not path then
        luatextra.internal_error(format("unable to find lua module %s", name))
    else
        if path:sub(1,2) == "./" then
            path = path:sub(3)
        end
        texio.write(' ('..path)
        dofile(path)
        if not luatextra.modules[name] then
            luatextra.internal_warning(format("You have requested module `%s',\n%s but the file %s does not provide it.", name, luatextra.internal_warning_spaces, filename))
        end
        if not package.loaded[name] then
            module(name, package.seeall)
        end
        texio.write(')')
    end
end

function luatextra.datetonumber(date)
    numbers = string.gsub(date, "(%d+)/(%d+)/(%d+)", "%1%2%3")
    return tonumber(numbers)
end

function luatextra.isdate(date)
    for _, _ in string.gmatch(date, "%d+/%d+/%d+") do
        return true
    end
    return false
end

local date, number = 1, 2

function luatextra.versiontonumber(version)
    if luatextra.isdate(version) then
        return {type = date, version = luatextra.datetonumber(version), orig = version}
    else
        return {type = number, version = tonumber(version), orig = version}
    end
end

luatextra.requiredversions = {}

function luatextra.require_module(name, version)
    if not name then
        return
    end
    if not version then
        return luatextra.use_module(name)
    end
    luaversion = luatextra.versiontonumber(version)
    if luatextra.modules[name] then
        if luaversion.type == date then
            if luatextra.datetonumber(luatextra.modules[name].date) < luaversion.version then
                luatextra.internal_error(format("found module `%s' loaded in version %s, but version %s was required", name, luatextra.modules[name].date, version))
            end
        else
            if luatextra.modules[name].version < luaversion.version then
                luatextra.internal_error(format("found module `%s' loaded in version %.02f, but version %s was required", name, luatextra.modules[name].version, version))
            end
        end
    else
        luatextra.requiredversions[name] = luaversion
        luatextra.use_module(name)
    end
end

function luatextra.provides_module(module)
    if not module then
        luatextra.internal_error('cannot provide nil module')
        return
    end
    if not module.version or not module.name or not module.date or not module.description then
        luatextra.internal_error('invalid module registered, fields name, version, date and description are mandatory')
        return
    end
    requiredversion = luatextra.requiredversions[module.name]
    if requiredversion then
        if requiredversion.type == date and requiredversion.version > luatextra.datetonumber(module.date) then
            luatextra.internal_error(format("loading module %s in version %s, but version %s was required", module.name, module.date, requiredversion.orig))
        elseif requiredversion.type == number and requiredversion.version > module.version then
            luatextra.internal_error(format("loading module %s in version %.02f, but version %s was required", module.name, module.version, requiredversion.orig))
        end
    end
    luatextra.modules[module.name] = module
    texio.write_nl('log', format("Lua module: %s %s v%.02f %s\n", module.name, module.date, module.version, module.description))
end

function luatextra.kpse_module_loader(module)
  local script = module .. ".lua"
  local file = kpse.find_file(script, "texmfscripts")
  if file then
    local loader, error = loadfile(file)
    if loader then
      texio.write_nl("(" .. file .. ")")
      return loader
    end
    return "\n\t[luatextra.kpse_module_loader] Loading error:\n\t"
           .. error
  end
  return "\n\t[luatextra.kpse_module_loader] Search failed"
end

table.insert(package.loaders, luatextra.kpse_module_loader)

luatextra.attributes = {}

tex.attributenumber = luatextra.attributes

function luatextra.attributedef(name, number)
    truename = name:gsub('[\\ ]', '')
    luatextra.attributes[truename] = tonumber(number)
end

luatextra.catcodetables = {}

tex.catcodetablenumber = luatextra.catcodetables

function luatextra.catcodetabledef(name, number)
    truename = name:gsub('[\\ ]', '')
    luatextra.catcodetables[truename] = tonumber(number)
end

do
    if luatextrapath then
        texio.write(')')
    end
end
