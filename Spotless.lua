--!strict
local Spotless = {}
Spotless.__index = Spotless

type SpotlessFunc = "Disconnect" | "Destroy" | "ClearChildren" | "Clear"

export type Void = (...any) -> ()
--[[Types
	@ValidThing: The thing to be cleaned up. This can be a RBXScriptConnection, Instance, function, or table.
	@SpotlessFunc: The method to call on the ValidThing for cleanup. This can be "Disconnect", "Destroy", "ClearChildren", or "Clear".
	@Void: A function that takes any number of arguments and returns nothing.
	@TaskRecord: A record of a task, containing the thing and its cleanup function.
	@SpotlessPrivate: Private fields for the Spotless class.
	@Spotless: Public Spotless type for type checking.
]]

export type ValidThing =
	RBXScriptConnection |
	Instance |
	() -> () |
	{ [any]: any } 

type TaskRecord = {
	thing: ValidThing,
	cleanupFunc: Void,
}
--Hello! </>
-- Private fields for Spotless
export type SpotlessPrivate = {
	_tasks: { TaskRecord },
	_linkedCleaners: { any }?,
	_cleaned: boolean?,
}

-- Public Spotless type (for type checking)
export type Spotless = typeof(setmetatable({} :: SpotlessPrivate, Spotless)) & {
	Add: (self: Spotless, thing: ValidThing, method: SpotlessFunc?) -> boolean,
	AddCleaner: (self: Spotless, otherCleaner: any) -> boolean,
	Cleanup: (self: Spotless) -> (),
	IsCleaned: (self: Spotless) -> boolean,
	DestroyThing: (self: Spotless, which: ValidThing) -> boolean,
	ReturnList: (self: Spotless) -> { TaskRecord },
}

function Spotless.Construct(): Spotless
	local self = setmetatable({
		_tasks = {},
		_linkedCleaners = nil,
		_cleaned = false,
	}, Spotless) :: any
	return self
end

function Spotless:Add(thing: ValidThing, method: SpotlessFunc?)
	if not thing then
		warn("[Spotless] Add called with nil thing")
		return false
	end
	
	if not method then
		if typeof(thing) == "RBXScriptConnection" then
			method = "Disconnect"
		elseif typeof(thing) == "Instance" then
			method = "Destroy"
		elseif typeof(thing) == "table" then
			if typeof(thing.Destroy) == "function" then
				method = "Destroy"
			elseif typeof(thing.Disconnect) == "function" then
				method = "Disconnect"
			elseif typeof(thing.ClearChildren) == "function" then
				method = "ClearChildren"
			elseif typeof(thing.Clear) == "function" then
				method = "Clear"
			end
		elseif typeof(thing) == "function" then
			method = nil
		else
			warn("[Spotless] Could not infer cleanup method for:", typeof(thing))
			return false
		end
	end
	
	local cleanupFunc: Void
	if typeof(thing) == "function" then
		cleanupFunc = thing
	elseif method and typeof(thing) == "table" and typeof(thing[method]) == "function" then
		cleanupFunc = function()
			thing[method](thing)
		end
	else
		warn("[Spotless] Invalid method or thing for cleanup:", method, typeof(thing))
		return false
	end
	
	table.insert(self._tasks, { thing = thing, cleanupFunc = cleanupFunc })
	return true
end

function Spotless:AddCleaner(otherCleaner)
	if typeof(otherCleaner) ~= "table" or typeof(otherCleaner.Cleanup) ~= "function" then --Other cleaner may not be functon!
		warn("[Spotless] AddCleaner called with invalid cleaner")
		return false
	end
	if not self._linkedCleaners then
		self._linkedCleaners = {}
	end
	table.insert(self._linkedCleaners, otherCleaner)
	return true
end

function Spotless:Cleanup()
	if self._cleaned then return end
	self._cleaned = true
	for _, task in ipairs(self._tasks) do
		local success, err = pcall(task.cleanupFunc)
		if not success then
			warn("[Spotless] Error cleaning up:", err)
		end
	end
	self._tasks = {}
	if self._linkedCleaners then
		for _, cleaner in ipairs(self._linkedCleaners) do
			if cleaner and cleaner.Cleanup then
				cleaner:Cleanup()
			end
		end
		self._linkedCleaners = {}
	end
end

function Spotless:IsCleaned()
	return self._cleaned == true
end

function Spotless:DestroyThing(which: ValidThing)
	for i = #self._tasks, 1, -1 do
		local task = self._tasks[i]
		if task.thing == which then
			local success, err = pcall(task.cleanupFunc)
			if not success then
				warn("[Spotless] Error cleaning up specific thing:", err)
			end
			table.remove(self._tasks, i)
			return true
		end
	end
	return false
end

function Spotless:Remove(which: ValidThing): boolean
	for i = #self._tasks, 1, -1 do
		local task = self._tasks[i]
		if task.thing == which then
			table.remove(self._tasks, i)
			return true
		end
	end
	return false
end

function Spotless:DestroySelf()
	self:Cleanup()
	setmetatable(self, nil)
	table.clear(self)
end


function Spotless:ReturnList()
	return self._tasks
end

function Spotless:Struct()
	return {
		_tasks = self._tasks,
		_linkedCleaners = self._linkedCleaners,
		_cleaned = self._cleaned,
	}
end 






--Short

return Spotless
