local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kinlei/ExternalLibrary/master/Module.lua"))() -- Requests API

local Tab = UI.createCategory('Tab Name') -- Creates tab/category

Tab:addToggle('Toggle', Callback) -- Boolean toggle with callback
Tab:addSlider('Slider', Callback, minimumValue, maximumValue, showDecimals, roundToNthDecimal) -- Slider with callback with minimum and maximum values
Tab:addButton('Button', Callback) -- Button with callback
