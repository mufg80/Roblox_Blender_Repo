local utilMod = {}

function utilMod.DistancetoGround(hrpX, hrpZ, ignoreList, npcHeight)
    local rayOrigin = Vector3.new(hrpX, 5000, hrpZ)
    local rayDirection = Vector3.new(0, -10000, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = ignoreList or {}
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if raycastResult then
        local distance = raycastResult.Position.Y + npcHeight
        return distance
    else
        return nil
    end
end



return utilMod