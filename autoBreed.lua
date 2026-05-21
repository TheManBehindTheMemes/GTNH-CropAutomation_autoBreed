local action = require('action')
local database = require('database')
local gps = require('gps')
local scanner = require('scanner')
local config = require('config')
local events = require('events')
local cropList = require('cropList')
local breedRates = require('breedRates')
local lowestStat = 0
local lowestStatSlot = 0
local isFinished = false
local parentCrop

--CHANGE ME; If you don't know how to use this properly, look at the README
local targetCrop = cropList[1] --set this to the crop you want to breed


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

        --check if the path is better
        elseif calculateOptimalPath() then
            parentCrop = crop
            action.transplant(gps.workingSlotToPos(slot), gps.workingSlotToPos(lowestStatSlot))
            action.placeCropStick(2)
            --update the farm to make that the highest stat slot, and everything else the lowest

        --check if mutations should be stored, and said crop isn't already in storage 
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

local function calculateOptimalPath()
    --these variables are all placeholders
    local steps1 = 0
    local steps2 = 0
    local chance1 = 0.0
    local chance2 = 0.0
    --Note: need to account for crops that require special conditions (such as saltyroot and redwheat)
    
    --check if new crop has a lower total chance
    if chance2 < chance1 then
    
        --check if it is more steps to the target crop
        if steps2 > steps1 then
            return false
        
        --check if it has less steps, and is within a certain range of probability
        elseif steps1 - steps2 > 0 and chance1 - chance2 <= 0.01 then
            return true

        --check if it is at least 2 steps more efficient
        elseif steps1 - steps2 >= 2 then
            return true

        --same amount of steps
        else
            return false
        end
    
    --check if new crop has a higher total chance
    elseif chance2 > chance1 then

        --check if it is less steps to the target crop
        if steps2 < steps1 then
            return true

        --check if it has more steps, but is within a certain range of probability
        elseif steps2 - steps1 < 2 and chance2 - chance1 >= 0.01 then
            return true

        --check if it is at least 2 steps less efficient
        elseif steps2 - steps1 >= 2 then
            return false

        --same amount of steps
        else
            return true
        end

    --same total chance
    else
        
        --has less steps
        if steps2 < steps1
            return true

        --has more steps
        elseif steps2 > steps1
            return false

        --has the same amount of steps
        else
            return false
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

    --Terminates the program if the target crop is not set
    if targetCrop == 'NULL' then
        print('ERROR: targetCrop is not defined. Please assign a crop to to targetCrop in autoBreed.lua, then restart the robot and try again.')
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
