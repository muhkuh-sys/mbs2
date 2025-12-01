local mTableUnlock = {}

--- Unlock a table which has been locked with TableLock.
--- This removes the method "__newindex" from the metatable.
--- The method will not be stored, so it will be lost after a call to this function.
---@param tbl table The table to unlock.
---@see TableLock
function mTableUnlock.TableUnlock(tbl)
  -- Get the metatable for tbl.
  local mt = getmetatable(tbl)
  if mt then
    -- A metatable exists. Remove the "__newindex" method.
    mt.__newindex = nil
    -- Update the metatable.
    setmetatable(tbl, mt)
  end
end

return mTableUnlock
