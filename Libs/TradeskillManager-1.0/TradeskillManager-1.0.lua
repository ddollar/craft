local TradeSkillManager, oldminor = LibStub:NewLibrary("TradeSkillManager-1.0", 1)

if not TradeSkillManager then return end

TradeSkillManager.recipes = {}

TradeSkillManager.on_scan = function(tradeskill, recipe) end

-- PUBLIC API ################################################################

function TradeSkillManager:Scan(tradeskill)
  CloseTradeSkill()
  CastSpellByName(tradeskill)

  local skillName, skillType, numAvailable, isExpanded, altVerb
  local reagentName, reagentTexture, reagentCount, playerReagentCount
  local recipe

  local num_recipes = GetNumTradeSkills()
  local i, j

  for i = 1, num_recipes do
    skillName, skillType, numAvailable, isExpanded, altVerb = GetTradeSkillInfo(i)

    if skillType ~= "header" then
      local reagents = {}
      local num_reagents = GetTradeSkillNumReagents(i)
      for j = 1, num_reagents do
        reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(i, j)

        if reagentName == nil then
          break
        end

        -- ENCHANTING

        -- if reagentName == "Lesser Cosmic Essence" then
        --   reagentName = "Greater Cosmic Essence"
        --   reagentCount = reagentCount / 3
        -- end

        -- END ENCHANTING

        reagents[reagentName] = {
          name  = reagentName,
          count = reagentCount
        }
      end

      -- ENCHANTING SPECIFIC

      if tradeskill == "Enchanting" then
        reagents["Enchanting Vellum"] = {
          name = "Enchanting Vellum",
          count = 1
        }
        skillName = "Scroll of " .. skillName
      end

      -- END ENCHANTING

      recipe = { name = skillName, reagents = reagents, index = i }

      self.on_scan(tradeskill, recipe)
      self:SaveRecipe(tradeskill, recipe)
    end
  end

  CloseTradeSkill()
end

function TradeSkillManager:RecipesMatching(tradeskill, func)
  local recipes = {}
  self:EachRecipe(tradeskill, function(recipe)
    if func(recipe) then
      recipes[recipe.name] = recipe
    end
  end)
  return recipes
end

function TradeSkillManager:Make(tradeskill, name, count)
  CloseTradeSkill()
  CastSpellByName(tradeskill)

  self:EachRecipe(tradeskill, function(recipe)
    if recipe.name == name then
      DoTradeSkill(recipe.index, count)
    end
  end)

  CloseTradeSkill()
end

-- EVENTS ####################################################################

function TradeSkillManager:OnScan(func)
  TradeSkillManager.on_scan = func
end

-- PRIVATE ###################################################################

function TradeSkillManager:EachRecipe(tradeskill, func)
  if not self.recipes[tradeskill] then return end
  for _, recipe in pairs(self.recipes[tradeskill]) do
    func(recipe)
  end
end

function TradeSkillManager:ClearTradeskill(tradeskill)
  self.recipes[tradeskill] = {}
end

function TradeSkillManager:SaveRecipe(tradeskill, recipe)
  if not self.recipes[tradeskill] then
    self.recipes[tradeskill] = {}
  end
  table.insert(self.recipes[tradeskill], recipe)
end

function TradeSkillManager:Print(message)
  DEFAULT_CHAT_FRAME:AddMessage(message)
end
