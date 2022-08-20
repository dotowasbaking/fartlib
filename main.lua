local uRequire = loadstring(game:HttpGet("https://raw.githubusercontent.com/dotowasbaking/-/main/utilRequire.lua", true))()

local utils = uRequire("miscUtils")
local Drawing = uRequire("drawingWrapper")
local maid = uRequire("maid").new()

local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local contextActionService = game:GetService("ContextActionService")

local shortenedInputNames = {["MouseButton1"] = "MB1", ["MouseButton2"] = "MB2", ["MouseButton3"] = "MB3", ["PageUp"] = "PUp", ["PageDown"] = "PDn", ["Home"] = "Hm", ["Delete"] = "Del", ["Insert"] = "Ins", ["LeftAlt"] = "LAlt", ["LeftControl"] = "LC", ["LeftShift"] = "LS", ["RightAlt"] = "RAlt", ["RightControl"] = "RC", ["RightShift"] = "RS", ["CapsLock"] = "Caps"}

local arrowKeys = {
    Enum.KeyCode.Up;
    Enum.KeyCode.Down;
    Enum.KeyCode.Left;
    Enum.KeyCode.Right;
}

local blacklistedKeys = {
    [Enum.KeyCode.Up] = true;
    [Enum.KeyCode.Down] = true;
    [Enum.KeyCode.Left] = true;
    [Enum.KeyCode.Right] = true;
    [Enum.KeyCode.Return] = true;
}

local UI_BASE_LAYER = 2048

local fartlib = {}

fartlib.__index = fartlib

function fartlib.new(options)
    local self = setmetatable({}, fartlib)

    self._configName = "__fartlib.cfg"
    self._pointerRegistry = {}

    self._connections = {}
    self._headerContainer = {}
    self._boundActionNames = {}

    self._elements = {}

    self._totalElements = 0
    self._visible = false

    self._baseWindow = Drawing.new("Square", {
        Color = Color3.fromRGB(20, 20, 20);
        Size = Vector2.new(220, 40);
        Position = Vector2.new(70, 100);
        ZIndex = UI_BASE_LAYER + 1;
        Filled = true;
    })

    self._baseBacking = Drawing.new("Square", {
        Color = Color3.fromRGB();
        Size = Vector2.new(224, 44);
        Position = Vector2.new(68, 98);
        ZIndex = UI_BASE_LAYER + 0;
        Filled = true;
        Transparency = 0.7;
    })

    self._accentLine = Drawing.new("Square", {
        Color = Color3.new(1, 0, 0);
        Size = Vector2.new(220, 2);
        Position = self._baseWindow.Position + Vector2.new(0, 30);
        ZIndex = UI_BASE_LAYER + 3;
        Filled = true;
    })

    self._titleText = Drawing.new("Text", {
        Color = Color3.new(1, 1, 1);
        Position = self._baseWindow.Position + Vector2.new(10, 9);
        Text = options.Title or "fartlib v1";
        Size = 13;
        ZIndex = UI_BASE_LAYER + 2;
        Font = 2;
    })

    self._selectionBar = Drawing.new("Image", {
        Data = utils:loadImage("https://i.ibb.co/k4pgrXh/fartlib-select.png");
        Size = Vector2.new(140, 14);
        ZIndex = UI_BASE_LAYER + 2;
        Transparency = 0;
    })

    local accentHue = 0; maid:AddTask(runService.Heartbeat:Connect(function(dt)
        accentHue %= 1
        local chromaColor = Color3.fromHSV(accentHue, 1, 1)
        self._accentLine.Color = chromaColor

        if self._chromaBind then
            self._chromaBind(chromaColor)
        end

        accentHue += 0.05 * dt
    end))

    return self
end

function fartlib:GetZIndex()
    return UI_BASE_LAYER
end

function fartlib:BindToChroma(func)
    self._chromaBind = func
end

function fartlib:_bindAction(actionName, callback, ...)
    self._boundActionNames[#self._boundActionNames + 1] = actionName

    contextActionService:BindCoreAction(actionName, callback, false, ...)
end

function fartlib:_unbindAction(actionName)
    table.remove(self._boundActionNames, table.find(self._boundActionNames, actionName))

    contextActionService:UnbindCoreAction(actionName)
end

function fartlib:_getNextElementPosition()
    local lastHeader = self._headerContainer[#self._headerContainer]

    if lastHeader then
        local lastElement = lastHeader._elements[#lastHeader._elements]

        if lastElement then
            return lastElement.Position + Vector2.new(0, 16)
        else
            return lastHeader.Position + Vector2.new(0, 16)
        end
    else
        return self._baseWindow.Position + Vector2.new(10, 38)
    end
end

function fartlib:SaveConfig()
    local pointerDictionary = {}

    for pointer, element in pairs(self._pointerRegistry) do
        pointerDictionary[pointer] = element:GetValue()
    end

    writefile(self._configName, ("return %s"):format(utils:tableToString(pointerDictionary)))
end

function fartlib:LoadConfig()
    local configTable = loadfile(self._configName)()

    for pointer, value in pairs(configTable) do
        local element = self._pointerRegistry[pointer]

        if element then
            element:SetValue(value)
        -- else
        --     notify here
        end
    end
end

function fartlib:Header(headerOptions)
    local headerPosition = self:_getNextElementPosition()
    local library = self
    local headerBase = {}
    
    headerBase._elements = {}
    headerBase.Position = headerPosition

    Drawing.new("Text", {
        Color = Color3.new(1, 1, 0);
        Position = headerPosition;
        Text = headerOptions.Title or "Undefined";
        Size = 13;
        ZIndex = UI_BASE_LAYER + 2;
        Font = 2;
    })

    self._baseWindow.Size = Vector2.new(220, headerPosition.Y + 22 - self._baseWindow.Position.Y)

    function headerBase:_registerElement(element)
        library._totalElements += 1
        library._elements[#library._elements + 1] = element
        library._baseWindow.Size = Vector2.new(220, element.Position.Y + 22 - library._baseWindow.Position.Y)
        library._baseBacking.Size = library._baseWindow.Size + Vector2.new(4, 4)

        if library._totalElements == 1 then
            library._selectedElement = element
            library._selectionBar.Position = element.Position + Vector2.new(-6, 0)
            library._selectionBar.Transparency = 1

            local directionalArrowPressed = false

            local function selectNext(inputObject)
                local firstElement = library._elements[1]
                local lastElement = library._elements[#library._elements]
                local selectedElementIndex = table.find(library._elements, library._selectedElement)
                local mult = inputObject.KeyCode == Enum.KeyCode.Down and 1 or -1
                local nextElement = library._elements[selectedElementIndex + (1 * mult)]
                local newSelectedElement = ((mult == 1 and (nextElement or firstElement)) or nextElement or lastElement) or firstElement

                library._selectedElement = newSelectedElement
                library._selectionBar.Position = newSelectedElement.Position + Vector2.new(-6, 0)
            end

            library:_bindAction(
                "__fartlibArrowControl",
                function(_, inputState, inputObject)
                    if not library._visible then
                        return
                    end

                    if inputState == Enum.UserInputState.Begin then
                        if inputObject.KeyCode == Enum.KeyCode.Down or inputObject.KeyCode == Enum.KeyCode.Up then
                            selectNext(inputObject)
                        else
                            if directionalArrowPressed then
                                return
                            end

                            if library._selectedElement.ArrowCallback then
                                directionalArrowPressed = true

                                local direction = inputObject.KeyCode == Enum.KeyCode.Left and 0 or 1

                                library._selectedElement.ArrowCallback(direction)

                                for _ = 1, 20 do
                                    if not userInputService:IsKeyDown(inputObject.KeyCode) then
                                        directionalArrowPressed = false

                                        return
                                    end

                                    task.wait(1/60)
                                end

                                while userInputService:IsKeyDown(inputObject.KeyCode) do
                                    library._selectedElement.ArrowCallback(direction)

                                    task.wait(1/40)
                                end

                                directionalArrowPressed = false
                            end
                        end
                    end
                end,
                unpack(arrowKeys)
            )
        end

        library:_bindAction(
            "__fartlibEnterControl",
            function(_, inputState)
                if not library._visible then
                    return
                end

                if inputState == Enum.UserInputState.Begin then
                    if library._selectedElement.EnterCallback then
                        library._selectedElement.EnterCallback()
                    end
                end
            end,
            Enum.KeyCode.Return
        )

        self._elements[#self._elements + 1] = element
    end

    function headerBase:Toggle(toggleOptions)
        local titlePosition = library:_getNextElementPosition()
        local toggleBase = {}

        toggleBase.Position = titlePosition
        toggleBase._state = toggleOptions.Enabled or false

        if toggleOptions.Pointer then
            library._pointerRegistry[toggleOptions.Pointer] = toggleBase
        end

        Drawing.new("Text", {
            Color = Color3.new(1, 1, 1);
            Position = titlePosition;
            Text = toggleOptions.Title or "Undefined Toggle";
            Size = 13;
            ZIndex = UI_BASE_LAYER + 3;
            Font = 2;
        })

        local stateDisplay; stateDisplay = Drawing.new("Text", {
            Color = toggleOptions.Enabled and Color3.fromRGB(70, 180, 70) or Color3.fromRGB(180, 70, 70);
            Position = Vector2.new(library._baseWindow.Position.X + library._baseWindow.Size.X - 10, titlePosition.Y);
            Text = toggleOptions.Enabled and "[on]" or "[off]";
            Size = 13;
            ZIndex = UI_BASE_LAYER + 2;
            Font = 2;
        })

        self:_registerElement(toggleBase)

        stateDisplay.Position = stateDisplay.Position + Vector2.new(-stateDisplay.TextBounds.X, 0)

        local function changeState()
            toggleBase:SetValue(not toggleBase._state)
        end

        toggleBase.ArrowCallback = changeState
        toggleBase.EnterCallback = changeState

        function toggleBase:SetValue(value)
            local originalValue = self._state
            self._state = value

            stateDisplay.Text = value and "[on]" or "[off]"
            stateDisplay.Color = value and Color3.fromRGB(70, 180, 70) or Color3.fromRGB(180, 70, 70)

            stateDisplay.Position = Vector2.new(library._baseWindow.Position.X + library._baseWindow.Size.X - 10, titlePosition.Y) + Vector2.new(-stateDisplay.TextBounds.X, 0)

            if originalValue ~= value then
                if toggleOptions.Callback then
                    toggleOptions.Callback(self._state)
                end
            end
        end

        function toggleBase:GetValue()
            return self._state
        end

        return toggleBase
    end

    function headerBase:Slider(sliderOptions)
        local sliderPosition = library:_getNextElementPosition()
        local sliderBase = {}

        sliderBase.Position = sliderPosition
        sliderBase._value = sliderOptions.Value

        if sliderOptions.Pointer then
            library._pointerRegistry[sliderOptions.Pointer] = sliderBase
        end

        Drawing.new("Text", {
            Color = Color3.new(1, 1, 1);
            Position = sliderPosition;
            Text = sliderOptions.Title or "Undefined Slider";
            Size = 13;
            ZIndex = UI_BASE_LAYER + 3;
            Font = 2;
        })

        local numberDisplay; numberDisplay = Drawing.new("Text", {
            Color = Color3.fromRGB(30, 100, 170);
            Position = Vector2.new(library._baseWindow.Position.X + library._baseWindow.Size.X - 10, sliderPosition.Y);
            Text = "["..sliderOptions.Value..(sliderOptions.Measurement or "").."]";
            Size = 13;
            ZIndex = UI_BASE_LAYER + 2;
            Font = 2;
        })

        self:_registerElement(sliderBase)

        numberDisplay.Position = numberDisplay.Position + Vector2.new(-numberDisplay.TextBounds.X, 0)

        sliderBase.ArrowCallback = function(direction)
            sliderBase:SetValue(sliderBase._value + (sliderOptions.Increment * (direction == 0 and -1 or 1)))
        end

        function sliderBase:SetValue(value)
            value = math.clamp(value, sliderOptions.Minimum, sliderOptions.Maximum)
            local originalValue = self._value
            self._value = value

            numberDisplay.Text = "["..(math.round(self._value * 100)/100)..(sliderOptions.Measurement or "").."]"
            numberDisplay.Position = Vector2.new(library._baseWindow.Position.X + library._baseWindow.Size.X - 10, sliderPosition.Y) + Vector2.new(-numberDisplay.TextBounds.X, 0)
   
            if self._value ~= originalValue then
                if sliderOptions.Callback then
                    sliderOptions.Callback(self._value)
                end
            end
        end

        function sliderBase:GetValue()
            return self._value
        end

        return sliderBase
    end

    function headerBase:Button(buttonOptions)
        local buttonPosition = library:_getNextElementPosition()
        local buttonBase = {}

        buttonBase.Position = buttonPosition

        Drawing.new("Text", {
            Color = Color3.new(1, 1, 1);
            Position = buttonPosition;
            Text = buttonOptions.Title or "Undefined Button";
            Size = 13;
            ZIndex = UI_BASE_LAYER + 3;
            Font = 2;
        })

        self:_registerElement(buttonBase)

        buttonBase.EnterCallback = function()
            if buttonOptions.Callback then
                buttonOptions.Callback()
            end
        end

        return buttonBase
    end

    function headerBase:Keybind(keybindOptions)
        local labelPosition = library:_getNextElementPosition()
        local keybindBase = {}

        keybindBase.Position = labelPosition
        keybindBase._value = keybindOptions.Keybind

        if keybindOptions.Pointer then
            library._pointerRegistry[keybindOptions.Pointer] = keybindBase
        end

        Drawing.new("Text", {
            Color = Color3.new(1, 1, 1);
            Position = labelPosition;
            Text = keybindOptions.Title or "Undefined Keybind";
            Size = 13;
            ZIndex = UI_BASE_LAYER + 3;
            Font = 2;
        })

        local keybindDisplay; keybindDisplay = Drawing.new("Text", {
            Color = Color3.fromRGB(230, 130, 10);
            Position = Vector2.new(library._baseWindow.Position.X + library._baseWindow.Size.X - 10, labelPosition.Y);
            Text = "none";
            Size = 13;
            ZIndex = UI_BASE_LAYER + 2;
            Font = 2;
        })

        self:_registerElement(keybindBase)

        keybindDisplay.Position = keybindDisplay.Position + Vector2.new(-keybindDisplay.TextBounds.X, 0)

        local actionName = ("__fartlibKeybind%i"):format(library._totalElements)
        local binded = false
        local binding = false

        function keybindBase:_bindKey(inputObject)
            if blacklistedKeys[inputObject] then
                return
            end

            if binded then
                library:_unbindAction(actionName)
            end

            if inputObject ~= nil and inputObject ~= Enum.KeyCode.Backspace then
                binded = true
                self._value = inputObject

                library:_bindAction(
                    actionName,
                    function(_, inputState)
                        if inputState == Enum.UserInputState.Begin then
                            if keybindOptions.Callback then
                                keybindOptions.Callback()
                            end

                            return keybindOptions.PassInput and Enum.ContextActionResult.Pass or Enum.ContextActionResult.Sink
                        end
                    end,
                    inputObject
                )

                keybindDisplay.Text = (shortenedInputNames[inputObject.Name] or inputObject.Name):lower()
                keybindDisplay.Position = Vector2.new(library._baseWindow.Position.X + library._baseWindow.Size.X - 10, labelPosition.Y) + Vector2.new(-keybindDisplay.TextBounds.X, 0)
            else
                library:_unbindAction(actionName)
                self._value = nil

                keybindDisplay.Text = "none"
                keybindDisplay.Position = Vector2.new(library._baseWindow.Position.X + library._baseWindow.Size.X - 10, labelPosition.Y) + Vector2.new(-keybindDisplay.TextBounds.X, 0)

                binded = false
            end
        end

        keybindBase.EnterCallback = function()
            if not binding then
                binding = true

                keybindDisplay.Text = "..."
                keybindDisplay.Position = Vector2.new(library._baseWindow.Position.X + library._baseWindow.Size.X - 10, labelPosition.Y) + Vector2.new(-keybindDisplay.TextBounds.X, 0)

                library:_bindAction(
                    "__fartlibBindKey",
                    function(_, inputState, inputObject)
                        if inputState == Enum.UserInputState.Begin then
                            keybindBase:_bindKey(inputObject.KeyCode)

                            if keybindOptions.ChangedCallback then
                                keybindOptions.ChangedCallback(inputObject.KeyCode)
                            end

                            library:_unbindAction("__fartlibBindKey")
                            binding = false
                        end
                    end,
                    table.unpack(Enum.KeyCode:GetEnumItems())
                )
            end
        end

        if keybindOptions.Keybind then
            keybindBase:_bindKey(keybindOptions.Keybind)
        end

        function keybindBase:SetValue(value)
            self:_bindKey(value)
        end

        function keybindBase:GetValue()
            return self._value
        end

        return keybindBase
    end

    library._headerContainer[#library._headerContainer + 1] = headerBase

    return headerBase
end

function fartlib:Initialize()
    self._visible = true

    for _, v in ipairs(Drawing.Drawings) do
        local originalTransparency = v.Transparency

        v.Transparency = 0
        v.Visible = true
        v.OriginalTransparency = originalTransparency
        
        task.spawn(function()
            for i = 0, originalTransparency, 0.025 do
                v.Transparency = i

                task.wait()
            end
        end)
    end
end

function fartlib:AddTask(...)
    return maid:AddTask(...)
end

function fartlib:CleanTask(...)
    return maid:CleanTask(...)
end

function fartlib:SetVisible(state)
    self._visible = state

    for _, v in ipairs(Drawing.Drawings) do
        v.Visible = state
    end
end

function fartlib:GetVisible()
    return self._visible
end

function fartlib:Destroy()
    maid:Destroy()

    for _, v in ipairs(self._boundActionNames) do
        contextActionService:UnbindCoreAction(v)
    end

    for _, v in ipairs(Drawing.Drawings) do
        v:Destroy()
    end

    setmetatable(self, nil)
end

return fartlib