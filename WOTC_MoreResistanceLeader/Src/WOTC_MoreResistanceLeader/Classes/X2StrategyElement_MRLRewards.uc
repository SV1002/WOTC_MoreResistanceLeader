class X2StrategyElement_MRLRewards extends X2StrategyElement_DefaultRewards config(MRL);

var config name ClassName;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Rewards;

    Rewards.AddItem(CreateMRLRewardTemplate());

    return Rewards;
}

static function X2DataTemplate CreateMRLRewardTemplate()
{
	local X2RewardTemplate Template;

	`CREATE_X2Reward_TEMPLATE(Template, 'Reward_ResistanceLeader');
	Template.rewardObjectTemplateName = 'Soldier';

	Template.GenerateRewardFn = GenerateMRLPersonnelReward;
	Template.SetRewardFn = SetPersonnelReward;
	Template.GiveRewardFn = GivePersonnelReward;
	Template.GetRewardStringFn = GetPersonnelRewardString;
	Template.GetRewardImageFn = GetPersonnelRewardImage;
	Template.GetBlackMarketStringFn = GetSoldierBlackMarketString;
	Template.GetRewardIconFn = GetGenericRewardIcon;
	Template.RewardPopupFn = PersonnelRewardPopup;

	return Template;
}

static function GenerateMRLPersonnelReward(XComGameState_Reward RewardState, XComGameState NewGameState, optional float RewardScalar = 1.0, optional StateObjectReference RegionRef)
{
	local XComGameState_Unit NewUnitState;
	local XComGameState_WorldRegion RegionState;
	local name nmCountry;
	
	// Grab the region and pick a random country
	nmCountry = '';
	RegionState = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(RegionRef.ObjectID));

	if(RegionState != none)
	{
		nmCountry = RegionState.GetMyTemplate().GetRandomCountryInRegion();
	}

	NewUnitState = CreateMRLUnit(NewGameState, RewardState.GetMyTemplate().rewardObjectTemplateName, nmCountry, (RewardState.GetMyTemplateName() == 'Reward_Rookie'));    
	RewardState.RewardObjectReference = NewUnitState.GetReference();
}

static function XComGameState_Unit CreateMRLUnit(XComGameState NewGameState, name nmCharacter, name nmCountry, optional bool bIsRookie)
{
	local XComGameStateHistory History;
	local XComGameState_Unit NewUnitState;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_HeadquartersResistance ResistanceHQ;
	local int idx, NewRank, StartingIdx;

	History = `XCOMHISTORY;

	//Use the character pool's creation method to retrieve a unit
	NewUnitState = `CHARACTERPOOLMGR.CreateCharacter(NewGameState, `XPROFILESETTINGS.Data.m_eCharPoolUsage, nmCharacter, nmCountry);
	NewUnitState.RandomizeStats();

	if (NewUnitState.IsSoldier())
	{
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		ResistanceHQ = XComGameState_HeadquartersResistance(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersResistance'));

		if (!NewGameState.GetContext().IsStartState())
		{
			ResistanceHQ = XComGameState_HeadquartersResistance(NewGameState.ModifyStateObject(class'XComGameState_HeadquartersResistance', ResistanceHQ.ObjectID));
		}

		NewUnitState.ApplyInventoryLoadout(NewGameState);
		NewRank = GetPersonnelRewardRank(true, bIsRookie);
		NewUnitState.SetXPForRank(NewRank);
		NewUnitState.StartingRank = NewRank;
		StartingIdx = 0;

		if(NewUnitState.GetMyTemplate().DefaultSoldierClass != '' && NewUnitState.GetMyTemplate().DefaultSoldierClass != class'X2SoldierClassTemplateManager'.default.DefaultSoldierClass)
		{
			// Some character classes start at squaddie on creation
			StartingIdx = 1;
		}

		for (idx = StartingIdx; idx < NewRank; idx++)
		{
			// Rank up to squaddie
			if (idx == 0)
			{
				NewUnitState.RankUpSoldier(NewGameState, default.ClassName);
				NewUnitState.ApplySquaddieLoadout(NewGameState);
				NewUnitState.bNeedsNewClassPopup = false;
			}
			else
			{
				NewUnitState.RankUpSoldier(NewGameState, NewUnitState.GetSoldierClassTemplate().DataName);
			}
		}

		// Set an appropriate fame score for the unit
		NewUnitState.StartingFame = XComHQ.AverageSoldierFame;
		NewUnitState.bIsFamous = true;

        // Minimum Genius		
		while (NewUnitState.ComInt < eComInt_Genius)
		{
			NewUnitState.ImproveCombatIntelligence();
		}

		`XEVENTMGR.TriggerEvent('RewardUnitGenerated', NewUnitState, NewUnitState); //issue #185 - fires off event with unit after they've been promoted to their reward rank
	}
	else
	{
		NewUnitState.SetSkillLevel(GetPersonnelRewardRank(false));
	}

	return NewUnitState;
}