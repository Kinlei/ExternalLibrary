if getgenv().ExternalAPI then
    return;
end

getgenv().ExternalAPI = true;

local V2 = Vector2.new;

local LeftTop, RightBot = V2(), V2();

local EventEnums = {
    MouseButton1Down = "MouseButton1Down",
	MouseButton1Up = "MouseButton1Up",
	MouseButton2Down = "MouseButton2Down",
	MouseButton2Up = "MouseButton2Up",
	MouseButton1Click = "MouseButton1Click",
	MouseButton2Click = "MouseButton2Click",
	MouseEnter = "MouseEnter",
	MouseLeave = "MouseLeave",
	MouseMoved = "MouseMoved",
	InputBegan = "InputBegan",
	InputChanged = "InputChanged",
	InputEnded = "InputEnded",
	Changed = "Changed",
	PositionChanged = "PositionChanged",
	AncestryChanged = "AncestryChanged",
	SizeChanged = "SizeChanged",
	ChildAdded = "ChildAdded",
}

local Event = {
    Enums = {},
    Events = {}
}

for Idx, Object in next, EventEnums do
    Event.Events[Idx] = Object;
end

local EventContainer = Instance.new("Folder");

function Event.new(Enum, ID)
    assert(EventEnums[Enum], "Attempted to call nil value: " .. tostring(Enum));
    local EventHolder = Event.Events[Enum][ID];
    if EventHolder then
        return EventHolder;
    end
    local NewEvent = Instance.new("BindableEvent");
    NewEvent.Parent = EventHolder;

    Event.Events[Enum][ID] = NewEvent;

    local Connection = {};

    function Connection:Connect(self, Callback, Timeout)
        local EventConnection = NewEvent.Event:Connect(Callback);

        if Timeout then
            delay(Timeout, function()
                EventConnection:Disconnect();
                EventConnection = nil;
            end)
        end

        return EventConnection;
    end

    function Connection:Wait(self, Timeout)
        local EventThread = coroutine.running();
        local EventConnection;

        EventConnection = NewEvent.Event:Connect(function(...)
            coroutine.resume(Thread, ...);
            EventConnection:Disconnect();
            EventConnection = nil;
        end)

        if Timeout then
            delay(Timeout, function()
                EventConnection:Disconnect();
                EventConnection = nil;
            end)
        end

        return coroutine.yield();
    end

    return Connection;
end

function Event.InvokeAll(self, Enum, ...)
    local Invokable = self.Events[Enum];
    if Invokable then
        for Idx, Event in next, Invokable do
            Event:Fire(...);
        end
    end
end

function Event.Invoke(self, Enum, ObjID, ...)
    self.Events[Enum][ObjID]:Fire(...);
end

function Event.DisconnectAll(self, ObjID)
    local Connections = self.Events[Enum][ObjID];
    if Connections then
        Connections:Destroy();
        self.Events[Enum][ObjID] = nil;
    end
end

local Drawings = {};

local InputService = game:GetService("UserInputService");
local Mouse = game:GetService("Players").LocalPlayer:GetMouse();

local InView, OutView = {}, {};

local LastRemoved, LastDown = {}, {};

function Remove(T, Idx)
    T[Idx] = T[#T];
    T[#T] = nil;
end

local MouseX, MouseY = Mouse.X, Mouse.Y;

Mouse.Move:Connect(function()
    MouseX, MouseY = Mouse.X, Mouse.Y;

    for Idx, Object in next, InView do
        local XCheck = (MouseX <= Object.LeftSide or MouseX >= Object.RightSide);
        local YCheck = (MouseY <= Object.TopSide or MouseY >= Object.BottomSide);
        if (XCheck or YCheck) then
            Remove(InView, Idx);
            table.insert(OutView, Object);
            LastRemoved[Object._ID] = tick();
            Event:Invoke("MouseLeave", Object._ID, MouseX, MouseY);
        else
            Event:Invoke("MouseMoved", Object._ID, MouseX, MouseY);
        end
    end

    for Idx, Object in next, OutView do
        local XCheck = (MouseX >= Object.LeftSide or MouseX <= Object.RightSide);
        local YCheck = (MouseY >= Object.TopSide or MouseY <= Object.BottomSide);
        if (XCheck and YCheck) then
            table.insert(InView, Object);
            Remove(OutView, Idx);
            Event:Invoke("MouseEnter", Object._ID, MouseX, MouseY);
        end
    end
end)

InputService.InputBegan:Connect(function(UserInput)
    local TypeInput = UserInput.UserInputType.Name;

    if TypeInput:find("MouseButton") then
        for Idx, Object in next, InView do
            local ObjID = Object._ID;
            LastDown[ObjID] = tick();
            Event:Invoke(TypeInput.."Down", ObjID, MouseX, MouseY);
            Event:Invoke("InputBegan", ObjID, UserInput);
        end
    else
        for Idx, Object in next, InView do
            local ObjID = Object._ID;
            Event:Invoke("InputBegan", ObjID, UserInput);
        end
    end
end)

InputService.InputChanged:Connect(function(UserInput, Processed)
    if Processed then return end;
    for Idx, Object in next, InView do
        Event:Invoke("InputEnded", Object._ID, UserInput);
    end
end)

InputService.InputEnded:Connect(function(UserInput, Processed)
    if Processed then return end;
    local TypeInput = UserInput.UserInputType.Name;

    if TypeInput:find("MouseButton") then
        for Idx, Object in next, InView do
            local ObjID = Object._ID;
            Event:Invoke(TypeInput.."Up", ObjID, MouseX, MouseY);
            Event:Invoke("InputEnded", ObjID, UserInput);
            if LastDown[ObjID] > LastRemoved[ObjID] then
                Event:Invoke(UserInput.."Click", ObjID, MouseX, MouseY);
            end
        end
    else
        for Idx, Object in next, InView do
            Event:Invoke("InputEnded", ObjID, UserInput);
        end
    end
end)

local DebugID = 0;

local RunService, TweenService = game:GetService("RunService"), game:GetService("TweenService");

local Supported = {
    Square = true,
    Line = true,
    Text = true,
    Circle = true,
    Triangle = true
}

function SolvePN(A,B,C)
    local BD = (B-A).unit;
    local CD = (C-A).unit;
    local BDB = BD:dot(BD);
    local BDC = BD:dot(CD);
    local CDC = CD:dot(CD);
    local PNS = (BDC - BDB)/(BDC - CDC);
    return -(BD + PNS*CD).unit;
end

function SolveTPNs(A,B,C)
    local AN, BN, CN = SolvePN(A,B,C), SolvePN(B,A,C), SolvePN(C,A,B);
    return A+AN,B+BN,C+CN;
end

local Parents = {};

local DrawingAPI;

DrawingAPI = hookfunction(Drawing.new, newcclosure(function(Class)
    return(function()
        local NewDrawing = DrawingAPI(Class);

        if Supported[Class] then
            DebugID = DebugID + 1;
            local DrawingObject = NewDrawing;
            local LocalID = DebugID;
            LastRemoved[LocalID] = 0;
            LastDown[DebugID] = 1;
            local Children = {};
            Parents[LocalID] = Children;

            local Shadow;

            local SizeConnection, PositionConnection, SizeAndPosConnection, TransparencyConnection;
            local IsCircle = (Class == "Circle");

            local Events = {};

            function Events:TweenSize(self, EndGoal, Direction, Style, Time, Override, Callback)
                if (SizeConnection and SizeConnection.Connected) then
                    if not Override then
                        return;
                    end
                    SizeConnection:Disconnect();
                end

                assert(typeof(EndGoal) == IsCircle and "number" or "Vector2", IsCircle and "Unexpected Size: "..tostring(EndGoal).."; number expected." or "Unexpected Size: "..tostring(EndGoal).."; Vector2 expected.");
                
                local CurrentTime = 0;
                Time = Time or 1;
                Style = Style or Enum.EasingStyle.Sine;
                Direction = Direction or Enum.EasingDirection.Out;

                local StartSize = DrawingObject[IsCircle and "Radius" or "Size"];

                SizeConnection = RunService.RenderStepped:Connect(function(Delta)
                    CurrentTime = CurrentTime + Delta;

                    if not IsCircle then
                        local NewSize = StartSize:Lerp(EndGoal, TweenService:GetValue(CurrentTime / Time, Style, Direction));
                        DrawingObject.Size = NewSize;
                    else
                        local Alpha = CurrentTime / Time;
                        DrawingObject.Radius = (StartSize*(1-Alpha)) + (EndGoal*Alpha);
                    end

                    if CurrentTime > Time then
                        if Callback then
                            coroutine.wrap(Callback)();
                        end
                        SizeConnection:Disconnect();
                        SizeConnection = nil;
                    end
                end)
            end

            function Events:TweenPosition(self, EndGoal, Direction, Style, Time, Override, Callback)
                if (PositionConnection and PositionConnection.Connected) then
                    if not Override then
                        return;
                    end
                    PositionConnection:Disconnect();
                end

                assert(typeof(EndGoal) == "Vector2", "Unexpected Position: "..tostring(EndGoal).."; Vector2 expected.");

                local CurrentTime = 0;
                Time = Time or 1;
                Style = Style or Enum.EasingStyle.Sine;
                Direciton = Direction or Enum.EasingDirection.Out;

                local Property = DrawingObject.Parent and "RelativePosition" or "Position";

                local StartPos = DrawingObject[Property];

                PositionConnection = RunService.RenderStepped:Connect(function(Delta)
                    CurrentTime = CurrentTime + Delta;

                    local NewPosition = StartPos:Lerp(EndGoal, TweenService:GetValue(CurrentTime / Time, Style, Direction));
                    DrawingObject[Property] = NewPosition;

                    if CurrentTime > Time then
                        if Callback then
                            coroutine.wrap(Callback)();
                        end
                        PositionConnection:Disconnect();
                        PositionConnection = nil;
                    end
                end)
            end

            function Events:TweenSizeAndPosition(self, EndSize, EndPos, Direction, Style, Time, Override, Callback)
                if (SizeAndPosConnection and SizeAndPosConnection.Connected) then
                    if not Override then
                        return;
                    end
                    SizeAndPosConnection:Disconnect();
                end

                assert(typeof(EndSize) == IsCircle and "number" or "Vector2", IsCircle and "Unexpected Size: "..tostring(EndSize).."; number expected." or "Unexpected Size: "..tostring(EndSize).."; Vector2 expected.");
                assert(typeof(EndSize) == "Vector2", "Unexpected Position: "..tostring(EndPos).."; Vector2 expected.");

                local CurrentTime = 0;
                Time = Time or 1;
                Style = Style or Enum.EasingStyle.Sine;
                Direction = Direction or Enum.EasingDirection.Out;

                local StartSize = DrawingObject[IsCircle and "Radius" or "Size"];
                
                local Property = DrawingObject.Parent and "RelativePosition" or "Position";

                local StartPos = DrawingObject[Property];

                SizeAndPosConnection = RunService.RenderStepped:Connect(function(Delta)
                    CurrentTime = CurrentTime + Delta;

                    local NewPosition = StartPos:Lerp(EndPos, TweenService:GetValue(CurrentTime / Time, Style, Direction));
                    DrawingObject[Property] = NewPosition;

                    if not IsCircle then
                        local NewSize = StartSize:Lerp(EndSize, TweenService:GetValue(CurrentTime / Time, Style, Direction));
                        DrawingObject.Size = NewSize;
                    else
                        local Alpha = CurrentTime / Time;
                        DrawingObject.Radius = (StartSize*(1-Alpha))+(EndSize*Alpha);
                    end

                    if CurrentTime > Time then
                        if Callback then
                            coroutine.wrap(Callback)();
                        end
                        SizeAndPosConnection:Disconnect();
                        SizeAndPosConnection = nil;
                    end
                end)
            end

            function Events:TweenTransparency(self, EndGoal, Direction, Style, Time, Override, Callback)
                if (TransparencyConnection and TransparencyConnection.Connected) then
                    if not Override then
                        return;
                    end
                    TransparencyConnection:Disconnect();
                end

                assert(typeof(EndGoal) == "number", "Unexpected Transparency: "..tostring(EndGoal).."; number expected.");

                EndGoal = math.clamp(EndGoal, 0, 1) or 0;

                local CurrentTime = 0;
                Time = Time or 1;
                Style = Style or Enum.EasingStyle.Sine;
                Direction = Direction or Enum.EasingDirection.Out;

                local StartTransparency = DrawingObject.Transparency;

                TransparencyConnection = RunService.RenderStepped:Connect(function(Delta)
                    CurrentTime = CurrentTime + Delta;

                    local Alpha = CurrentTime / Time;
                    local Lerped = (StartTransparency*(1-Alpha)) + (EndGoal*Alpha);

                    DrawingObject.Transparency = Lerped;

                    if CurrentTime > Time or (Lerped < 0 or Lerped > 1) then
                        if Callback then
                            coroutine.wrap(Callback)();
                        end
                        TransparencyConnection:Disconnect();
                        TransparencyConnection = nil;
                    end
                end)
            end

            if IsCircle then
                Events.TweenRadius = Events.TweenSize;
                Events.TweenRadiusAndPosition = Events.TweenSizeAndPosition;
                Events.TweenSize = nil;
                Events.TweenSizeAndPosition = nil;
            end

            for Idx, Enum in next, EventEnums do
                local NewEvent = Event.new(Enum, DebugID);
                Events[Idx] = NewEvent;
            end

            local RelativePosition = V2();
            local ParentPosition = V2();
            local SetParent, ParentConnection;
            local RelativeTo, RelativeFrom = RelativePosition, RelativePosition;

            local function UpdateEdges(Pos, Size)
                local PX, PY = Pos.X, Pos.Y;

                Events.LeftSide = XPos;
                Events.RightSide = XPos + Size.X;
                Events.TopSide = YPos;
                Events.BottomSide = YPos + Size.Y;

                Event:Invoke("PositionChanged", LocalID, Pos);
                Event:Invoke("SizeChanged", LocalID, Size);
            end

            local function ParentSetFunction(self, Key, Value)
                if Value == nil then
                    local ParentHolder = Parents[SetParent._ID];
                    local ChildIndex = table.find(ParentHolder, DrawingObject);
                    if ChildIndex then
                        Remove(ParentHolder, ChildIndex);
                    end
                    ParentPosition = nil;
                    if ParentConnection then
                        ParentConnection:Disconnect();
                        ParentConnection = nil;
                    end
                    return;
                end
                SetParent = Value;

                table.insert(Parents[Value._ID], DrawingObject);
                ParentPosition = Value.Position;

                if Class == "Line" then
                    DrawingObject.From = ParentPosition + RelativeFrom;
                    DrawingObject.To = ParentPosition + RelativeTo;
                else
                    local NewPosition = ParentPosition + RelativePosition;
                    Event:Invoke("PositionChanged", LocalID, NewPosition);
                    DrawingObject.Position = NewPosition;

                    if Shadow then
                        Shadow.Position = NewPosition - V2(1,1);
                    end
                    if not IsCircle then
                        UpdateEdges(DrawingObject.Position, (Class == "Text") and DrawingObject.TextBounds or DrawingObject.Size);
                    end
                end

                ParentConnection = Value.PositionChanged:Connect(function(NewPosition)
                    if (Class == "Line") then
                        DrawingObject.To = NewPosition + RelativeTo;
                        DrawingObject.From = NewPosition + RelativeFrom;
                    else
                        local NewPosition = NewPosition + RelativePosition;
                        Event:Invoke("PositionChanged", LocalID, NewPosition);
                        DrawingObject.Position = NewPosition;

                        if Shadow then
                            Shadow.Position = NewPosition - V2(1,1);
                        end
                        if not IsCircle then
                            UpdateEdges(NewPosition, (Class == "Text") and DrawingObject.TextBounds or DrawingObject.Size);
                        end
                    end
                    ParentPosition = NewPosition;
                end)

                Event:Invoke("AncestryChanged", LocalID, Value);
            end

            local function RelativePositionFunction(self, Key, Value)
                RelativePosition = Value;
                if ParentPosition then
                    local NewPosition = ParentPosition + RelativePosition;
                    Event:Invoke("PositionChanged", LocalID, NewPosition);
                    DrawingObject.Position = NewPosition;
                    if not IsCircle then
                        UpdateEdges(NewPosition, (Class == "Text") and DrawingObject.TextBounds or DrawingObject.Size);
                    end
                end
            end

            function Events:GetChildren()
                return Children;
            end

            if Class == "Square" then
                local Pos, Size = DrawingObject.Position, DrawingObject.Size;
                UpdateEdges(Pos, Size);

                Shadow = DrawingAPI("Square");
                Shadow.Size = Size + V2(2,2);
                Shadow.Position = Pos - V2(1,1);
                Shadow.Transparency = 1;
                Shadow.Thickness = 1;
                Shadow.Color = Color3.fromRGB(0,0,0);
                Shadow.Filled = false;

                local OutlineTransparency = false;

                local function RemoveDrawing()
                    for _, Child in next, Children do
                        Child:Remove();
                    end
                    Shadow:Remove();
                    DrawingObject:Remove();
                end

                Events.Remove = RemoveDrawing;
                Events.Destroy = RemoveDrawing;

                NewDrawing = setmetatable(Events, {
                    __newindex = function(self, Key, Value)
                        if Key == "Visible" then
                            if Value then
                                Shadow.Visible = OutlineTransparency;
                                table.insert(OutView, NewDrawing);
                            else
                                Shadow.Visible = false;
                                local Idx = table.find(OutView, NewDrawing);
                                if Idx then
                                    Remove(OutView, Idx);
                                end
                            end
                        elseif Key == "Parent" then
                            return ParentSetFunction(self, Key, Value);
                        elseif Key == "RelativePosition" then
                            return RelativePositionFunction(self, Key, Value);
                        elseif Key == "Size" then
                            UpdateEdges(DrawingObject.Position, Value);
                            Shadow.Size = Value + V2(2,2);
                        elseif Key == "Position" then
                            Event:Invoke("PositionChanged", LocalID, Value);
                            UpdateEdges(Value, DrawingObject.Size);
                            Shadow.Position = Value - V2(1,1);
                        elseif Key == "Outline" then
                            Event:Invoke("Changed", LocalID, Key, Value);
                            OutlineTransparency = Value;
                            return;
                        elseif Key == "OutlineSize" then
                            Shadow.Thickness = Value;
                        elseif Key == "OutlineTransparency" then
                            Shadow.Transparency = Value;
                        elseif Key == "OutlineColor" then
                            Shadow.Color = Value;
                        elseif Key == "ZIndex" then
                            Shadow.ZIndex = Value;
                        end
                        Event:Invoke("Changed", LocalID, Key, Value);
                        DrawingObject[Key] = Value;
                    end,
                    __index = function(self, Key)
                        if Key == "_ID" then
                            return LocalID;
                        elseif Key == "Outline" then
                            return OutlineTransparency;
                        elseif Key == "OutlineSize" then
                            return Shadow.Thickness;
                        elseif Key == "OutlineTransparency" then
                            return Shadow.Transparency;
                        elseif Key == "OutlineColor" then
                            return Shadow.Color;
                        elseif Key == "Parent" then
                            return SetParent;
                        elseif Key == "RelativePosition" then
                             return RelativePosition;
                        end
                        return DrawingObject[Key];
                    end
                });
                table.insert(Drawings, NewDrawing);
            elseif Class == "Text" then
                local Pos, Size = DrawingObject.Position, DrawingObject.TextBounds;
                UpdateEdges(Pos, Size);

                NewDrawing = setmetatable(Events, {
                    __newindex = function(self, Key, Value)
                        if Value then
                            table.insert(OutView, NewDrawing);
                        else
                            local Idx = table.find(OutView, NewDrawing);
                            if Idx then
                                Remove(OutView, Idx);
                            end
                        end
                        if Key == "Parent" then
                            return ParentSetFunction(self, Key, Value);
                        elseif Key == "RelativePosition" then
                            return RelativePositionFunction(self, Key, Value);
                        elseif Key == "Size" or Key == "Text" then
                            DrawingObject[Key] = Value;

                            UpdateEdges(DrawingObject.Position, DrawingObject.TextBounds);
                            return;
                        elseif Key == "Position" then
                            Event:Invoke("PositionChanged", LocalID, Value);
                            UpdateEdges(Value, DrawingObject.TextBounds);
                        end;
                        Event:Invoke("Changed", LocalID, Value);
                        DrawingObject[Key] = Value;
                    end,
                    __index = function(self, Key)
                        if Key == "_ID" then
                            return LocalID;
                        elseif Key == "Parent" then
                            return SetParent;
                        elseif Key == "RelativePosition" then
                            return RelativePosition;
                        end
                        return DrawingObject[Key];
                    end
                });
                table.insert(Drawings, NewDrawing);
            elseif Class == "Line" then
                NewDrawing = setmetatable(Events, {
                    __newindex = function(self, Key, Value)
                        if Key == "Parent" then
                            ParentSetFunction(self, Key, Value);
                            return;
                        elseif Key == "RelativeTo" then
                            RelativeTo = Value;
                            if ParentPosition then
                                DrawingObject.To = ParentPosition + Value;
                            end
                            return;
                        elseif Key == "RelativeFrom" then
                            RealtiveFrom = Value;
                            if ParentPosition then
                                DrawingObject.From = ParentPosition + Value;
                            end
                            return;
                        end
                        DrawingObject[Key] = Value;
                    end,
                    __index = function(self, Key)
                        if Key == "_ID" then
                            return LocalID;
                        elseif Key == "Parent" then
                            return SetParent;
                        elseif Key == "RelativeTo" then
                            return RelativeTo;
                        elseif Key == "RelativeFrom" then
                            return RelativeFrom;
                        end
                        return DrawingObject[Key];
                    end
                })
                table.insert(Drawings, NewDrawing);
            elseif Class == "Triangle" then
                local Outlines = {};

                local Edges = {SolveTPNs(DrawingObject.PointA, DrawingObject.PointB, DrawingObject.PointC)};

                Edges[0] = Edges[3];

                for Idx = 1, 3 do
                    local NewLine = DrawingAPI("Line");
                    NewLine.Thickness = 1;
                    NewLine.Color = Color3.new();
                    NewLine.From = Edges[Idx];
                    NewLine.To = Edges[Idx - 1];
                    Outlines[Idx] = NewLine;
                end

                local function RemoveTri()
                    for _, Line in next, Outlines do
                        Line:Remove();
                    end
                    DrawingObject:Remove();
                end

                Events.Remove = RemoveTri;
                Events.Destroy = RemoveTri;

                local OutlineVis = false;

                NewDrawing = setmetatable(Events, {
                    __newindex = function(self, Key, Value)
                        if Key == "Outline" then
                            OutlineVis = Value;
                            if DrawingObject.Visible then
                                for Idx = 1, 3 do
                                    Outlines[Idx].Visible = Value;
                                end
                            end
                            return;
                        elseif Key == "OutlineThickness" then
                            for Idx = 1, 3 do
                                Outlines[Idx].Thickness = Value;
                            end
                            return;
                        elseif Key == "OutlineColor" then
                            for Idx = 1, 3 do
                                Outlines[Idx].Color = Value;
                            end;
                            return;
                        elseif Key == "Visible" then
                            for Idx = 1, 3 do
                                Outlines[Idx].Visible = OutlineVis and Value;
                            end;
                        elseif Key == "OutlineTransparency" then
                            for Idx = 1, 3 do
                                Outlines[Idx].Transparency = Value;
                            end
                        elseif Key:find("Point") then
                            DrawingObject[Key] = Value;
                            Edges = {SolveTPNs(DrawingObject.PointA, DrawingObject.PointB, DrawingObject.PointC)};

                            Edges[0] = Edges[3];

                            for Idx = 1, 3 do
                                local NewLine = DrawingAPI("Line");
                                NewLine.Thickness = 1;
                                NewLine.Color = Color3.new();
                                NewLine.From = Edges[Idx];
                                NewLine.To = Edges[Idx - 1];
                                Outlines[Idx] = NewLine;
                            end
                            return;
                        end;
                        DrawingObject[Key] = Value;
                    end,
                    __index = function(self, Key)
                        if Key == "_ID" then
                            return LocalID;
                        end;
                        return DrawingObject[Key];
                    end;
                });
                table.insert(Drawings, NewDrawing);
            elseif Class == "Circle" then
                NewDrawing = setmetatable(Events, {
                    __newindex = function(self, Key, Value)
                        if Key == "Parent" then
                            return ParentSetFunction(self, Key, Value);
                        elseif Key == "RelativePosition" then
                            return RelativePositionFunction(self, Key, Value);
                        end;
                        DrawingObject[Key] = Value;
                    end,
                    __index = function(self, Key)
                        if Key == "_ID" then
                            return LocalID;
                        elseif Key == "RelativePosition" then
                            return RelativePosition;
                        elseif Key == "Parent" then
                            return SetParent;
                        end
                        return DrawingObject[Key];
                    end
                });
                table.insert(Drawings, NewDrawing);
            end
        end
        return NewDrawing;
    end)
end))
