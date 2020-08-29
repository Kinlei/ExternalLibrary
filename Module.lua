loadstring(game:HttpGet("https://raw.githubusercontent.com/Kinlei/ExternalLibrary/master/Events.lua"))();

local UI = {};

UI.categoryOffset = 40;
UI.yOffset = 40;
UI.buttonXSize = 160;
UI.buttonSize = 25;
UI.debugTime = 25;
UI.buttonOffset = {};

UI.playerMouse = game:GetService'Players'.LocalPlayer:GetMouse();

local mouseDot = External.new'Square';
mouseDot.Size = Vector2.new(1, 1);
mouseDot.Filled = true;
mouseDot.Color = Color3.new(1, 1, 1);
mouseDot.Visible = true;

UI.playerMouse.Move:Connect(function()
	topPos = Vector2.new(UI.playerMouse.X, UI.playerMouse.Y + 36);
	mouseDot.Position = topPos;
end);

local UIS = game:GetService'UserInputService';
local isMouseButtonDown;
UIS.InputBegan:Connect(function(Input)
	if Input.UserInputType.Name == 'MouseButton1' then
		isMouseButtonDown = true;
	end;
end);
UIS.InputEnded:Connect(function(Input)
	if Input.UserInputType.Name == 'MouseButton1' then
		isMouseButtonDown = false;
	end;
end);

local roundToNthDecimal = function(num, n)
	n = n or 1;
	return math.floor(num * n + 0.5) / n;
end;
local tweenService = game:GetService'TweenService';
local runService = game:GetService'RunService';
UI.createCategory = function(Name)
	local topHolder = External.new'Square';
	local localizedOffset = UI.categoryOffset;

	topHolder.Visible = true;
	topHolder.Filled = true;
	topHolder.Color = Color3.fromRGB(30, 32, 33);
	topHolder.Size = Vector2.new(UI.buttonXSize, UI.buttonSize);
	topHolder.Position = Vector2.new(localizedOffset, UI.yOffset);

	UI.buttonOffset[topHolder] = 28;

	local holderDecor = External.new'Line';
	local fromYOffset = UI.yOffset + UI.buttonSize - 1;

	holderDecor.Visible = true;
	holderDecor.Parent = topHolder;
	holderDecor.Color = Color3.new(0.8588235294117647, 0.1843137254901961, 0.1843137254901961);
	holderDecor.relativeFrom = Vector2.new(0, UI.buttonSize - 1);
	holderDecor.relativeTo = Vector2.new(UI.buttonXSize, UI.buttonSize - 1);
	holderDecor.Thickness = 2;

	UI.categoryOffset = localizedOffset + topHolder.Size.X + UI.buttonSize + 4;
	local Category = {};

	local function newBase()	
		local Base = External.new'Square';
		Base.Size = Vector2.new(UI.buttonXSize, UI.buttonSize);
		Base.Parent = topHolder;
		Base.relativePosition = Vector2.new(0, UI.buttonOffset[topHolder]);
		Base.Color = Color3.fromRGB(30, 32, 33);
		Base.Visible = true;
		Base.Filled = true;

		UI.buttonOffset[topHolder] = UI.buttonOffset[topHolder] + UI.buttonSize;

		return Base, Base.Position;
	end;
	local function newRelative(Base, relativePosition, Type, Size, Text)
		local Relative = External.new(Type);
		Relative.relativePosition = relativePosition;
		Relative.Parent = Base;

		Relative.Visible = true;
		Relative.Transparency = 1;
		Relative.Size = Type == 'Text' and 12 or Size;
		
		if Type == 'Text' then
			Relative.Text = Text;
			Relative.Color = Color3.new(1, 1, 1);
		elseif Type == 'Square' then
			Relative.Filled = true;
			Relative.Color = Color3.fromRGB(24, 24, 24);
		end;

		return Relative;
	end;

	newRelative(topHolder, Vector2.new(4, 4), 'Text', nil, Name);
	local Toggle = newRelative(topHolder, Vector2.new(UI.buttonXSize - 15, 4), 'Text', nil, '-');

	local uiToggle;
	local Debounce;
	local buttonOrder = {};

	local isDown;
	topHolder.MouseButton1Down:Connect(function(X, Y)
		isDown = true;
		local clickedAt = Vector2.new(UI.playerMouse.X, UI.playerMouse.Y) - topHolder.Position;
		while isDown do
			topHolder.Position = Vector2.new(UI.playerMouse.X - clickedAt.X, UI.playerMouse.Y - clickedAt.Y);

			runService.RenderStepped:Wait();
		end;
	end);
	topHolder.MouseButton1Up:Connect(function()
		isDown = false;
	end);
	Toggle.MouseButton1Down:Connect(function()
		if Debounce then
			return;
		end;
		Toggle.Text = uiToggle and '-' or '+';
		uiToggle = not uiToggle;
		Debounce = true;

		
		local isToggling = uiToggle;

		local numChildren = #topHolder:GetChildren();
		local waitFor = 0.1 * (numChildren / 4);

		local yieldFor = waitFor / numChildren;
		for i = uiToggle and #buttonOrder or 1, not uiToggle and #buttonOrder or 1, uiToggle and -1 or 1 do
			local Objs = buttonOrder[i];
			for Obj, Size in next, Objs do
				if type(Size) == 'number' then
					coroutine.wrap(function()
						for i =  uiToggle and 1 or 0, uiToggle and -0.2 or 1.2, uiToggle and -0.6 or 0.6 do
							Obj.Transparency = math.clamp(i, 0, 1);
							wait();
						end;
					end)();
				else
					Obj:TweenSize(Vector2.new(Size.X, uiToggle and 0 or Size.Y), nil, nil, yieldFor, nil, nil, true);
				end;
			end;
			wait(yieldFor);
		end;

		Debounce = false;
	end);

	Category.addToggle = function(self, Name, Callback)
		local Base, Offset = newBase();
		local Text = newRelative(Base, Vector2.new(4, 4), 'Text', nil, Name);

		local toggleHolder = newRelative(Base, Vector2.new(UI.buttonXSize - 21.5, 2.5), 'Square', Vector2.new(20, 20));
		toggleHolder.Color = Color3.fromRGB(24, 24, 24);
		local toggleSquare = newRelative(Base, Vector2.new((UI.buttonXSize - 19.5) + 8, 4), 'Square', Vector2.new(0, 0));
		toggleSquare.Color = Color3.fromRGB(140, 140, 140);
		local squareSize = {
			[Base] = Base.Size,
			[toggleSquare] = toggleSquare.Size,
			[Text] = Text.Transparency,
			[toggleHolder] = toggleHolder.Size
		};

		local Toggle;
		Base.MouseButton1Down:Connect(function()
			Toggle = not Toggle;
			if Callback then
				Callback(Toggle);
			end;
			local posNum = Toggle and 0 or 8;
			local sizeNum = Toggle and 16 or 0;
			toggleSquare:TweenSizeAndPosition(Vector2.new(sizeNum, sizeNum), Vector2.new((UI.buttonXSize - 19.5) + posNum, posNum + 4), nil, nil, 0.1, true);
			squareSize[toggleSquare] = Vector2.new(sizeNum, sizeNum);
		end);

		table.insert(buttonOrder, squareSize);
	end;
	Category.addSlider = function(self, Name, Callback, minimumValue, maximumValue, Increment, incrementBy)
		local Base, Offset = newBase();
		local nameText = newRelative(Base, Vector2.new(4, 4), 'Text', nil, Name);
		local sliderBase = newRelative(Base, Vector2.new(4, 2), 'Square', Vector2.new(154, 20));
		local sliderLine = newRelative(Base, Vector2.new(77, 1), 'Square', Vector2.new(2, 18));

		sliderLine.Color = Color3.fromRGB(80, 80, 80);
		sliderBase.Color = Color3.fromRGB(24, 24, 24);
		sliderLine.Parent = sliderBase;

		local squareSize = {
			[Base] = Base.Size, 
			[sliderBase] = sliderBase.Size, 
			[nameText] = nameText.Transparency,
			[sliderLine] = sliderLine.Size
		};
		local function offsetText()
			nameText.relativePosition = Vector2.new((UI.buttonXSize / 2) - (nameText.TextBounds.X / 2), 4);
		end;
		offsetText();

		local isSliding;
		sliderBase.MouseButton1Down:Connect(function(mouseX, mouseY)
			isSliding = true;
			while isSliding and isMouseButtonDown do
				local xSize = sliderBase.Size.X - 1;
				local baseXPos = sliderBase.Position.X;

				local posOffset = UI.playerMouse.X - baseXPos;
				posOffset = math.clamp(posOffset, 0, xSize);

				sliderLine:TweenPosition(Vector2.new(math.max(posOffset - 2, 1), 1), nil, nil, 0.05);

				local Amount = minimumValue + ((maximumValue - minimumValue) * (posOffset / xSize));
				Amount = Increment and roundToNthDecimal(Amount, incrementBy) or math.floor(Amount + 0.5);
				nameText.Text = Name .. ': ' .. Amount offsetText();
				if Callback then
					Callback(Amount);
				end;
				runService.RenderStepped:Wait();
			end;
		end);
		sliderBase.MouseButton1Up:Connect(function(mouseX, mouseY)
			isSliding = false;
		end);

		table.insert(buttonOrder, squareSize);
	end;
	Category.addButton = function(self, Name, Callback)
		local Base, Offset = newBase();
		local nameText = newRelative(Base, Vector2.new(4, 4), 'Text', nil, Name);
		local buttonBase = newRelative(Base, Vector2.new(4, 2), 'Square', Vector2.new(154, 20));
		nameText.relativePosition = Vector2.new((UI.buttonXSize / 2) - (nameText.TextBounds.X / 2), 4);

		buttonBase.MouseButton1Click:Connect(function()
			if Callback then
				Callback();
			end;
		end);
		buttonBase.MouseButton1Down:Connect(function()
			buttonBase.Color = Color3.fromRGB(120, 120, 120);
		end);
		buttonBase.MouseButton1Up:Connect(function()
			buttonBase.Color = Color3.fromRGB(24, 24, 24);
		end);
		local squareSize = {
			[Base] = Base.Size, 
			[buttonBase] = buttonBase.Size, 
			[nameText] = nameText.Transparency
		};
		table.insert(buttonOrder, squareSize);
	end;

	return Category;
end;

game:GetService'StarterGui':SetCore('SendNotification', {
	Title = 'Credits',
	Text = 'UI Library made by Pyseph#7777',
	Duration = 5
});

return UI;
