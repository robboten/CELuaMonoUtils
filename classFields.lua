---@diagnostic disable: lowercase-global

function findClassIdByName(name)
    local cId = mono_findClass('', name)
    if cId == nil then return end
    print(string.format("Class name: %s - cId: %X", name, cId))
    return cId
end

local function findClassFields(cId)
    local fields = mono_class_enumFields(cId)
    print("Nr fields: " .. #fields)
    return fields
end


local function findClassInstances(cId)
    local instances = mono_class_findInstancesOfClassListOnly('', cId, false)
    printf("Instance Type: %s - Count %i", type(instances), #instances)
    return instances
end

------------------------------------------------

local function varTypeValue(f, v)
    local value = nil
    if f.typename == 'System.Int32' then
        value = readInteger(v + f.offset)
    elseif f.typename == 'System.Int64' then
        value = readQword(v + f.offset)
    elseif f.typename == 'System.Int16' then
        value = readSmallInteger(v + f.offset)
    elseif f.typename == 'System.String' then
        value = readStringOffset(v + f.offset)
    elseif f.typename == 'System.Double' then
        value = readDouble(v + f.offset)
    elseif f.typename == 'System.Single' then
        value = readFloat(v + f.offset)
    elseif f.typename == 'System.Boolean' then
        if readBytes(v + f.offset, 1, false) == 1 then value = "true" else value = "false" end
    elseif f.typename == 'System.String[]' then
        value = readArray(v + f.offset, 'String')
    elseif f.typename == 'System.Int32[]' then
        value = readArray(v + f.offset, 'Int32')
    else
        local tmp = readInteger(v + f.offset)
         --print(string.format("temp: %X %s", tmp, f.typename))
        if f.typename then
            if ends_with(f.typename,"Model") and tmp and tmp ~= 0  then
                value = getClassInstanceFields(tmp, f.typename)
            end
        elseif tmp and tmp ~= 0 then
            value = string.format("@%.8X", tmp)
        else
            value = "nil"
        end
    end

    return value
end

local function getFieldsProps(classFields, fieldId)
    local fTable = {}
    for _, f in ipairs(classFields) do
        if not f.Static or f.offset > 0 then
            local value = varTypeValue(f, fieldId)
            --print(string.format("%X", fieldId))
            if value then
                local tempTable={
                    address=string.format("%X", fieldId + f.offset),
                    offset = string.format("%X", f.offset),
                    name = f.name,
                    type = f.typename,
                    value = value
                }

                table.insert(fTable, tempTable)
            end
        end
    end
    return fTable
end

local function getClassInstancesFields(cId)
    --get instances for class
    local classInstances = findClassInstances(cId)
    --get fields for class
    local fields = findClassFields(cId)

    local fieldsTable = {}
    --if table - loop thru instances table and get their field values
    if type(classInstances) == 'table' then
        for _, fieldId in pairs(classInstances) do
            --print(string.format("%X",fieldId))
            table.insert(fieldsTable, getFieldsProps(fields, fieldId))
        end
    else
        print(type(classInstances) .. " - Not a table")
    end

    return fieldsTable
end


function getClassInstanceFields(instanceAddress, className)
    local cId = findClassIdByName(className)
    local fields = findClassFields(cId)

    local fTable = {}

    for _, f in ipairs(fields) do
        if f.offset > 0 then
            local value = varTypeValue(f, instanceAddress)

            --print(string.format("%X",instanceAddress))
            if value then
                local tempTable={
                    Address=string.format("%X", instanceAddress + f.offset),
                    Offset = string.format("%X", f.offset),
                    Name = f.name,
                    Type = f.typename,
                    Value = value,
                    Class = string.format("%X", cId)

                }

                table.insert(fTable, tempTable)
            end
        end
    end
    --dumpTable(fTable2,2)
    return fTable
end


-----------------------------------
--- Utils ---
-----------------------------------

function ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
 end

function readArray(address, valueType)
    local child = readPointer(address)
    if child ~= nil and child ~= 0 then
        local count = readInteger(child + 0xc)
        if count == nil then return nil end
        if count < 200 then
            local arr = {}
            for i = 1, count do
                local v
                if valueType == 'String' then
                    v = readStringOffset(child + 0xc + 0x4 * i)
                elseif valueType == 'Int32' then
                    v = readInteger(child + 0xc + 0x4 * i, true)
                end
                if v and v ~= '' then
                    table.insert(arr, v)
                end
            end
            return "[" .. table.concat(arr, ', ') .. "]"
        else
            return nil
        end
    end
end

function readStringOffset(address)
    --print(string.format("stringread %X",address))
    local child = readPointer(address)

    if child then
        --print(string.format("stringread2 %X",child))
        local strLen = readInteger(child + 0x8)

        if strLen then
            --print(string.format("stringread3 %X %i", address, strLen))
            return readString(child + 0xc, strLen * 2, true)
        end
    end
end

-------------------------------------

function dumpTable(table, depth)
    if (depth > 200) then
        print("Error: Depth > 200 in dumpTable()")
        return
    end
    for k, v in pairs(table) do
        if (type(v) == "table") then
            print(string.rep("  ", depth) .. k .. ":")
            dumpTable(v, depth + 1)
        else
            print(string.rep("  ", depth) .. k .. ": ", v)
        end
    end
end

------------------------------------------------------------------------

if process == nil then
    ShowMessage('Process is not selected.')
elseif readInteger(process) == 0 then
    ShowMessage('Process cannot be opened. Gone?')
else
    if (monopipe ~= nil) and (monopipe.ProcessID ~= getOpenedProcessID()) then
        monopipe.destroy()
        monopipe = nil
    end
    if (monopipe == nil) then
        LaunchMonoDataCollector()
        -- monoSymbolList is only available if the target is il2cpp and not normal mono
        --while (monoSymbolList==nil) or (not monoSymbolList.FullyLoaded) do checkSynchronize(50) end -- checkSynchronize requires that memRec is ASynch.
    end
end

local cId = findClassIdByName('Girl')
local t = getClassInstancesFields(cId)
dumpTable(t, 3)
--getClassInstanceFields(readInteger(0x15C459CC),"BoyModel")

--return t

--printClassFieldsRaw(findClassFields(cId))
--local vt=findClassInstances(cId)
--printTableSimple(vt)
--local fields=getClassFields(findClassFields(cId))
--printClassFields(fields)

--printFieldInstance(0x15dcc770)
