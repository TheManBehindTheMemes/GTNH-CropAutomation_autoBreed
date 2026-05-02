local action = require('action')
local database = require('database')
local gps = require('gps')
local scanner = require('scanner')
local config = require('config')
local events = require('events')
local lowestStat = 0
local lowestStatSlot = 0
local isFinished = false

--CHANGE ME; to learn how to set this correctly, look at the cropList file
local targetCrop = cropList[1] --set this to the crop you want to breed
local parentCrop


-- ===================== FUNCTIONS ======================

local function updateLowest()
    local farm = database.getFarm()
    lowestStat = 99
    lowestStatSlot = 0

    -- Find lowest stat slot
    for slot=1, config.workingFarmArea, 2 do
        local crop = farm[slot]
        if crop.isCrop then

            if crop.name == 'air' or crop.name == 'emptyCrop' then
                lowestStat = 0
                lowestStatSlot = slot
                break

            elseif crop.name ~= targetCrop then
                local stat = crop.gr + crop.ga - crop.re - 2
                if stat < lowestStat then
                    lowestStat = stat
                    lowestStatSlot = slot
                end

            else
                local stat = crop.gr + crop.ga - crop.re
                if stat < lowestStat then
                    lowestStat = stat
                    lowestStatSlot = slot
                end
            end
        end
    end
end

local function findEmpty()
    local farm = database.getFarm()

    for slot=1, config.workingFarmArea, 2 do
        local crop = farm[slot]
        if crop ~= nil and (crop.name == 'air' or crop.name == 'emptyCrop') then
            emptySlot = slot
            return true
        end
    end
    return false
end

local function checkChild(slot, crop)
    if crop.isCrop and crop.name ~= 'emptyCrop' then

        if crop.name == 'air' then
            action.placeCropStick(2)

        elseif crop.name == targetCrop then
            isFinished = true
            action.transplant(gps.workingSlotToPos(slot), gps.storageSlotToPos(database.nextStorageSlot()))
            action.placeCropStick(2)
            database.addToStorage(crop)
            return

        elseif firstRun then
            return

        elseif crop.name == parentCrop then
            local stat = crop.gr + crop.ga - crop.re

            -- Make sure no parent on the working farm is empty
            if stat >= config.autoStatThreshold and findEmpty() and crop.gr <= config.workingMaxGrowth and crop.re <= config.workingMaxResistance then
                action.transplant(gps.workingSlotToPos(slot), gps.workingSlotToPos(emptySlot))
                action.placeCropStick(2)
                database.updateFarm(emptySlot, crop)

            -- No parent is empty, check if it has higher stats than the lowest stat parent
            elseif stat > lowestStat then
                action.transplant(gps.workingSlotToPos(slot), gps.workingSlotToPos(lowestStatSlot))
                action.placeCropStick(2)
                database.updateFarm(lowestStatSlot, crop)
                updateLowest()

            -- Stats are not high enough
            else
                action.deweed()
                action.placeCropStick()
            end

        elseif config.keepMutations and (not database.existInStorage(crop)) then
            action.transplant(gps.workingSlotToPos(slot), gps.storageSlotToPos(database.nextStorageSlot()))
            action.placeCropStick(2)
            database.addToStorage(crop)

        else
            action.deweed()
            action.placeCropStick()
        end
    end
end

local function checkParent(slot, crop)
    if crop.isCrop and crop.name ~= 'air' and crop.name ~= 'emptyCrop' then
        if scanner.isWeed(crop, 'working') then
            action.deweed()
            database.updateFarm(slot, {isCrop=true, name='emptyCrop'})
        end
    end
end

-- ====================== THE LOOP ======================

local function runOnce(firstRun)
    for slot=1, config.workingFarmArea, 1 do

        -- Terminal Condition
        if #database.getStorage() >= config.storageFarmArea then
            print('autoBreed: Storage Full!')
            return false
        end

        --Terminal Condition
        if isFinished then
            print('Target crop bred successfully!')
            return false
        end

        --Terminal Condition
        if events.needExit() then
            print('autoBreed: Received Exit Command!')
            return false
        end

        os.sleep(0)

        --Scan
        gps.go(gps.workingSlotToPos(slot))
        local crop = scanner.scan()

        if firstRun then
            database.updateFarm(slot, crop)
            if slot == 1 then
                parentCrop = database.getFarm()[1].name
                print(string.format('autoBreed: attempting to breed %s with %s', targetCrop, parentCrop))
            end
        end

        if slot % 2 == 0 then
            checkChild(slot, crop, firstRun)
        else
            checkParent(slot, crop, firstRun)
        end

        if action.needCharge() then
            action.charge()
        end
    end
    return true
end

-- ====================== MAIN ======================

local function main()
    action.initWork()

    --Terminates the program if the target crop or parent crop is not set
    if targetCrop == 'NULL' or parentCrop == 'NULL' then
        print('ERROR: targetCrop or parentCrop is not defined. Please assign a crop to to targetCrop and parentCrop, then restart the robot and try again.')
        needExitFlag = true
    end

    -- First Run
    runOnce(true)
    action.restockAll()
    updateLowest()

    -- Loop
    while runOnce(false) do
        action.restockAll()
    end

    -- Terminated Early
    if events.needExit() then
        action.restockAll()
    end

    -- Finish
    if config.cleanUp then
        action.cleanUp()
    end
    
    events.unhookEvents()
    print('autoBreed: Complete!')
end

main()
