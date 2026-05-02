--this file will contain all practical outcomes of breeding a crop
local cropList = require('cropList')
local breedRates = {}
--contains the number of possible types children (excluding itself, grass, and weed)
local possibleChildren = {67,55,57,80,92,79,55,40,94,82,67,57,77,64,79,83,91,77,7,68,45,77,49,108,107,58,83,59,95,77,77,17,38,108,66,98,66,67,5,81,70,81,102,15,52,44,63,97,3,67,82,50,92,72,90,82,8,95,91,41,55,99,107,61,91,73,108,79,74,55,75,67,46,11,108,22,59,2,77,93,83,74,86,86,62,98,84,74,6,71,107,94,49,82,96,49,1,71,91,33,39,108,77,37,33,61,47,88,50,66,98,103,97,37,107,79,81,66,95,7,97,60,67,97,35,29,11,92,83,77,66,111,82,81,76,60,82,40,108,6,5,65,51,39,71,73,48,58,49,46,94,61,9}

--this loop fills out the 3d array with the parent crop, all possible child crops, and how likely it is to be bred
for parent=1, #cropList do
  breedRates[parent] = cropList[parent]
  for child=1, possibleChildren[parent] do
    breedrates[parent][child] = 'filler' --placeholder
    breedRates[parent][child][1] = 0.0 --placeholder
return breedRates
