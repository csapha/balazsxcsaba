local StoryHelpers = require(script.Parent.StoryHelpers)

return function(target)
	return StoryHelpers.mount("UpgradeController", target)
end
