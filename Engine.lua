local AutoRob = {}

local keys, network = loadstring(game:HttpGet("https://raw.githubusercontent.com/RobloxAvatar/JailWare/main/Fetcher.lua"))()

local replicated_storage = game:GetService("ReplicatedStorage");
local run_service = game:GetService("RunService");
local pathfinding_service = game:GetService("PathfindingService");
local players = game:GetService("Players");
local tween_service = game:GetService("TweenService");

local player = players.LocalPlayer;

local dependencies = {
    variables = {
        up_vector = Vector3.new(0, 500, 0),
        raycast_params = RaycastParams.new(),
        path = pathfinding_service:CreatePath({WaypointSpacing = 3}),
        player_speed = 80, 
        vehicle_speed = 250
    },
    modules = {
        ui = require(replicated_storage.Module.UI),
        store = require(replicated_storage.App.store),
        player_utils = require(replicated_storage.Game.PlayerUtils),
        vehicle_data = require(replicated_storage.Game.Garage.VehicleData)
    },
    helicopters = {Heli = true}, -- heli is included in free vehicles
    motorcycles = {Volt = true}, -- volt type is "custom" but works the same as a motorcycle
    free_vehicles = {},
    unsupported_vehicles = {},
    door_positions = {}    
};

local movement = {};
local utilities = {};

--// function to toggle if a door can be collided with

function utilities:toggle_door_collision(door, toggle)
    for index, child in next, door.Model:GetChildren() do 
        if child:IsA("BasePart") then 
            child.CanCollide = toggle;
        end; 
    end;
end;

--// function to get the nearest vehicle that can be entered

function utilities:get_nearest_vehicle(tried) -- unoptimized
    local nearest;
    local distance = math.huge;

    for index, action in next, dependencies.modules.ui.CircleAction.Specs do -- all of the interations
        if action.IsVehicle and action.ShouldAllowEntry == true and action.Enabled == true and action.Name == "Enter Driver" then -- if the interaction is to enter the driver seat of a vehicle
            local vehicle = action.ValidRoot;

            if not table.find(tried, vehicle) and workspace.VehicleSpawns:FindFirstChild(vehicle.Name) then
                if not dependencies.unsupported_vehicles[vehicle.Name] and (dependencies.modules.store._state.garageOwned.Vehicles[vehicle.Name] or dependencies.free_vehicles[vehicle.Name]) and not vehicle.Seat.Player.Value then -- check if the vehicle is supported, owned and not already occupied
                    if not workspace:Raycast(vehicle.Seat.Position, dependencies.variables.up_vector, dependencies.variables.raycast_params) then
                        local magnitude = (vehicle.Seat.Position - player.Character.HumanoidRootPart.Position).Magnitude; 
            
                        if magnitude < distance then 
                            distance = magnitude;
                            nearest = vehicle;
                        end;
                    end;
                end;
            end;
        end;
    end;

    return nearest;
end;

--// function to pathfind to a position with no collision above

function movement:pathfind(tried)
    local distance = math.huge;
    local nearest;

    local tried = tried or {};
    
    for index, value in next, dependencies.door_positions do -- find the nearest position in our list of positions without collision above
        if not table.find(tried, value) then
            local magnitude = (value.position - player.Character.HumanoidRootPart.Position).Magnitude;
            
            if magnitude < distance then 
                distance = magnitude;
                nearest = value;
            end;
        end;
    end;

    table.insert(tried, nearest);

    utilities:toggle_door_collision(nearest.instance, false);

    local path = dependencies.variables.path;
    path:ComputeAsync(player.Character.HumanoidRootPart.Position, nearest.position);

    if path.Status == Enum.PathStatus.Success then -- if path making is successful
        local waypoints = path:GetWaypoints();

        for index = 1, #waypoints do 
            local waypoint = waypoints[index];
            
            player.Character.HumanoidRootPart.CFrame = CFrame.new(waypoint.Position + Vector3.new(0, 2.5, 0)); -- walking movement is less optimal

            if not workspace:Raycast(player.Character.HumanoidRootPart.Position, dependencies.variables.up_vector, dependencies.variables.raycast_params) then -- if there is nothing above the player
                utilities:toggle_door_collision(nearest.instance, true);

                return;
            end;

            task.wait(0.05);
        end;
    end;

    utilities:toggle_door_collision(nearest.instance, true);

    movement:pathfind(tried);
end;

--// function to interpolate characters position to a position

function movement:move_to_position(part, cframe, speed, car, target_vehicle, tried_vehicles)
    local vector_position = cframe.Position;
    
    if not car and workspace:Raycast(part.Position, dependencies.variables.up_vector, dependencies.variables.raycast_params) then -- if there is an object above us, use pathfind function to get to a position with no collision above
        movement:pathfind();
        task.wait(0.5);
    end;
    
    local y_level = 500;
    local higher_position = Vector3.new(vector_position.X, y_level, vector_position.Z); -- 500 studs above target position

    repeat -- use velocity to move towards the target position
        local velocity_unit = (higher_position - part.Position).Unit * speed;
        part.Velocity = Vector3.new(velocity_unit.X, 0, velocity_unit.Z);

        task.wait();

        part.CFrame = CFrame.new(part.CFrame.X, y_level, part.CFrame.Z);
    until (part.Position - higher_position).Magnitude < 10;

    part.CFrame = CFrame.new(part.Position.X, vector_position.Y, part.Position.Z);
    part.Velocity = Vector3.new(0, 0, 0);
end;

function AutoRob.MakeNotification(txt, time)
    local p = loadstring(game:HttpGet("https://raw.githubusercontent.com/RobloxAvatar/JailWare/main/Notify.lua"))()
	p:MakeNotification({Name = "JailWare", Content = txt, Time = time})
end

function AutoRob.Teleport(cframe)
    movement:move_to_position(player.Character.HumanoidRootPart, cframe, dependencies.variables.player_speed); 
end

function AutoRob.FarmTP(cframe)
    local tried = tried or {};
    local nearest_vehicle = utilities:get_nearest_vehicle(tried);
    
for i,v in pairs(game:GetService("Workspace").Vehicles:GetChildren()) do
        if nearest_vehicle:FindFirstChild("Seat") then
            if nearest_vehicle.Seat.PlayerName.Value == "" then
                local dist = (nearest_vehicle.PrimaryPart.Position - game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position).magnitude
                if dist <= 1100 then
                movement:move_to_position(player.Character.HumanoidRootPart, nearest_vehicle.Seat.CFrame, dependencies.variables.player_speed);
                wait(0.5)   
                local enter_attempts = 1;

        repeat -- attempt to enter car
            network:FireServer(keys.EnterCar, nearest_vehicle, nearest_vehicle.Seat);
                    
            enter_attempts = enter_attempts + 1;

            task.wait(0.1);
        until enter_attempts == 10 or nearest_vehicle.Seat.PlayerName.Value == player.Name;

        if nearest_vehicle.Seat.PlayerName.Value ~= player.Name then -- if it failed to enter, try a new car
                    table.insert(tried, nearest_vehicle);

                    return tp3(cframe, tried or {nearest_vehicle});
                end;
                    break
                end
            end
        end
    end

    wait(0.5)
    for i,v in pairs(game:GetService("Workspace").Vehicles:GetChildren()) do
        if v:FindFirstChild("Seat") then
            if v.Seat.PlayerName.Value == game:GetService("Players").LocalPlayer.Name then
                if dependencies.helicopters[v.Name] then
                   -- movement:move_to_position(nearest_vehicle.Model.TopDisc, cframe, dependencies.variables.vehicle_speed);
                   print("Heli")
                   v.Model.TopDisc.CFrame = v.Model.TopDisc.CFrame + Vector3.new(0, 500, 0)
                    vtp(v.Model.TopDisc, cframe + Vector3.new(0, 500, 0))
                    v.Model.TopDisc.CFrame = v.Model.TopDisc.CFrame + Vector3.new(0, -400, 0)
                    task.wait(0.15);
                    for _,d in pairs(require(game:GetService("ReplicatedStorage").Module.UI).CircleAction.Specs) do
                        if d.Part == v.Seat then
                            d:Callback(d,true)
                        end
                    end
                    task.wait(0.15);
                    if ExitCar then
        local replicated_storage = game:GetService("ReplicatedStorage");
		
            local game_folder = replicated_storage.Game;
            local team_choose_ui = require(game_folder.TeamChooseUI);    
            local exit_car_function = getupvalue(team_choose_ui.Init, 3);

            exit_car_function()
    end
                    --network:FireServer(keys.ExitCar)
                elseif dependencies.motorcycles[v.Name] then
                    --movement:move_to_position(nearest_vehicle.CameraVehicleSeat, cframe, dependencies.variables.vehicle_speed);
                    v.CameraVehicleSeat.CFrame = v.CameraVehicleSeat.CFrame + Vector3.new(0, 500, 0)
                    vtp(nearest_vehicle.CameraVehicleSeat, cframe + Vector3.new(0, 500, 0))
                    v.CameraVehicleSeat.CFrame = v.CameraVehicleSeat.CFrame + Vector3.new(0, -500, 0)
                    task.wait(0.15);
                    for _,d in pairs(require(game:GetService("ReplicatedStorage").Module.UI).CircleAction.Specs) do
                        if d.Part == v.Seat then
                            d:Callback(d,true)
                        end
                    end
                    task.wait(0.15);
                    if ExitCar then
        local replicated_storage = game:GetService("ReplicatedStorage");
		
            local game_folder = replicated_storage.Game;
            local team_choose_ui = require(game_folder.TeamChooseUI);    
            local exit_car_function = getupvalue(team_choose_ui.Init, 3);

            exit_car_function()
    end
                    --network:FireServer(keys.ExitCar)
                elseif v.Name == "DuneBuggy" then
                    --movement:move_to_position(nearest_vehicle.BoundingBox, cframe, dependencies.variables.vehicle_speed);
                    v.BoundingBox.CFrame = v.BoundingBox.CFrame + Vector3.new(0, 500, 0)
                    vtp(nearest_vehicle.BoundingBox, cframe + Vector3.new(0, 500, 0))
                    v.BoundingBox.CFrame = v.BoundingBox.CFrame + Vector3.new(0, -500, 0)
                    task.wait(0.15);
                    for _,d in pairs(require(game:GetService("ReplicatedStorage").Module.UI).CircleAction.Specs) do
                        if d.Part == v.Seat then
                            d:Callback(d,true)
                        end
                    end
                    task.wait(0.15);
                    if ExitCar then
        local replicated_storage = game:GetService("ReplicatedStorage");
		
            local game_folder = replicated_storage.Game;
            local team_choose_ui = require(game_folder.TeamChooseUI);    
            local exit_car_function = getupvalue(team_choose_ui.Init, 3);

            exit_car_function()
    end
                    --network:FireServer(keys.ExitCar)
                elseif v.Name == "Chassis" then
                    --movement:move_to_position(v.PrimaryPart, cframe, dependencies.variables.vehicle_speed);
                else
                    --movement:move_to_position(nearest_vehicle.PrimaryPart, cframe, dependencies.variables.vehicle_speed);
                    nearest_vehicle.PrimaryPart.CFrame = v.PrimaryPart.CFrame + Vector3.new(0, 500, 0)
                    vtp(v.PrimaryPart, cframe + Vector3.new(0, 500, 0))
                    nearest_vehicle.PrimaryPart.CFrame = nearest_vehicle.PrimaryPart.CFrame + Vector3.new(0, -500, 0)
                    --G_17_(cframe)
                    task.wait(0.15);
                    for _,d in pairs(require(game:GetService("ReplicatedStorage").Module.UI).CircleAction.Specs) do
                        if d.Part == v.Seat then
                            d:Callback(d,true)
                        end
                    end
                    task.wait(0.15);
                    if ExitCar then
        local replicated_storage = game:GetService("ReplicatedStorage");
		
            local game_folder = replicated_storage.Game;
            local team_choose_ui = require(game_folder.TeamChooseUI);    
            local exit_car_function = getupvalue(team_choose_ui.Init, 3);

            exit_car_function()
    end
                    local deez = game:GetService("VirtualInputManager")

			local function Ib(ic)
				deez:SendKeyEvent(true, ic, false, game)
				wait()
				deez:SendKeyEvent(false, ic, false, game)
			end
            --Ib("E")
                    --network:FireServer(keys.ExitCar)
                end
            end
        end
    end
end

function AutoRob.Punch()
    local replicated_storage = game:GetService("ReplicatedStorage");
    local game_folder = replicated_storage.Game;
    local default_actions = require(game_folder.DefaultActions);
    local punch_function = getupvalue(default_actions.punchButton.onPressed, 1).attemptPunch;
    punch_function()
end
