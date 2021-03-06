package stats
{
	import database.BgReading;
	import database.CGMBlueToothDevice;
	import database.CommonSettings;
	import database.Database;
	
	import model.ModelLocator;
	
	import treatments.Treatment;
	import treatments.TreatmentsManager;
	
	import ui.chart.helpers.GlucoseFactory;
	
	import utils.MathHelper;
	import utils.TimeSpan;

	public class StatsManager
	{
		public function StatsManager()
		{
			throw new Error("StatsManager is not meant to be instantiated!");
		}
		
		public static function getBasicUserStats(fromTime:Number = Number.NaN, untilTime:Number = Number.NaN, page:String = "all"):BasicUserStats
		{
			if (!CGMBlueToothDevice.isFollower())
			{
				var masterUserStats:BasicUserStats = Database.getBasicUserStats(fromTime, untilTime, page);
				if (masterUserStats == null)
					masterUserStats = new BasicUserStats(page);
				
				return masterUserStats;
			}
			else
			{
				var followerUserStats:BasicUserStats = new BasicUserStats(page);
				var now:Number = new Date().valueOf();
				var lowTreshold:Number = Number(CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_LOW_MARK));;
				var highTreshold:Number = Number(CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_HIGH_MARK));
				var high:int = 0;
				var inRange:int = 0;
				var low:int = 0;
				var dataLength:int = ModelLocator.bgReadings.length;
				var realReadingsNumber:int = 0;
				var totalGlucose:Number = 0;
				var cleanReadings:Array = [];
				var i:int;
				
				if (page == BasicUserStats.PAGE_ALL || page == BasicUserStats.PAGE_BG_DISTRIBUTION || page == BasicUserStats.PAGE_VARIABILITY)
				{
					//Calculations
					for (i = 0; i < dataLength; i++) 
					{
						var bgReading:BgReading = ModelLocator.bgReadings[i];
						
						if (now - bgReading.timestamp > TimeSpan.TIME_24_HOURS - TimeSpan.TIME_30_SECONDS || bgReading._calculatedValue == 0)
							continue;
						
						var glucoseValue:Number = Number(bgReading._calculatedValue);
						
						cleanReadings.push( { calculatedValue: glucoseValue, timestamp: bgReading._timestamp } );
						
						if(glucoseValue >= highTreshold)
							high += 1;
						else if (glucoseValue > lowTreshold && glucoseValue < highTreshold)
							inRange += 1;
						else if (glucoseValue <= lowTreshold)
							low += 1;
						
						totalGlucose += glucoseValue;
						realReadingsNumber++;
					}
				}
				
				if (page == BasicUserStats.PAGE_ALL || page == BasicUserStats.PAGE_BG_DISTRIBUTION)
				{
					followerUserStats.numReadingsHigh = high;
					followerUserStats.numReadingsLow = low;
					followerUserStats.numReadingsInRange = inRange;
					followerUserStats.percentageHigh = (high * 100) / realReadingsNumber;
					followerUserStats.percentageHighRounded = (( followerUserStats.percentageHigh * 10 + 0.5)  >> 0) / 10;
					followerUserStats.percentageInRange = (inRange * 100) / realReadingsNumber;
					followerUserStats.percentageInRangeRounded = (( followerUserStats.percentageInRange * 10 + 0.5)  >> 0) / 10;
					var preLow:Number = Math.round((low * 100) / realReadingsNumber) * 10 / 10;
					
					if (followerUserStats.numReadingsLow == 0)
					{
						followerUserStats.percentageLow = 0;
						followerUserStats.percentageLowRounded = 0;
					}
					else if ( preLow != 0 && !isNaN(preLow))
					{
						followerUserStats.percentageLow = 100 - followerUserStats.percentageInRange - followerUserStats.percentageHigh;
						followerUserStats.percentageLowRounded = Math.round ((100 - followerUserStats.percentageInRangeRounded - followerUserStats.percentageHighRounded) * 10) / 10;
					}
					
					//Overcome AS3 number precision limitation
					if (followerUserStats.percentageHighRounded == 0 && followerUserStats.percentageLowRounded == 0)
					{
						followerUserStats.percentageHigh = 0;
						followerUserStats.percentageLow = 0;
						followerUserStats.percentageInRange = 100;
						followerUserStats.percentageInRangeRounded = 100;
					}
					else if (followerUserStats.percentageHighRounded == 0 && followerUserStats.percentageInRangeRounded == 0)
					{
						followerUserStats.percentageHigh = 0;
						followerUserStats.percentageInRange = 0;
						followerUserStats.percentageLow = 100;
						followerUserStats.percentageLowRounded = 100;
					}
					else if (followerUserStats.percentageLowRounded == 0 && followerUserStats.percentageInRangeRounded == 0)
					{
						followerUserStats.percentageLow = 0;
						followerUserStats.percentageInRange = 0;
						followerUserStats.percentageHigh = 100;
						followerUserStats.percentageHighRounded = 100;
					}
					
					followerUserStats.averageGlucose = (( (totalGlucose / realReadingsNumber) * 10 + 0.5)  >> 0) / 10;
					if (realReadingsNumber != 0)
					{
						followerUserStats.a1c = (( ((46.7 + followerUserStats.averageGlucose) / 28.7) * 10 + 0.5)  >> 0) / 10;
						if (CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_PIE_CHART_A1C_IFCC_ON) == "true")
							followerUserStats.a1c = ((((followerUserStats.a1c - 2.15) * 10.929) * 10 + 0.5)  >> 0) / 10; //IFCC support
					}
					followerUserStats.captureRate = ((((realReadingsNumber * 100) / 288) * 10 + 0.5)  >> 0) / 10;
					if (followerUserStats.captureRate > 100) followerUserStats.captureRate = 100;
					followerUserStats.numReadingsTotal = realReadingsNumber;
					followerUserStats.numReadingsDay = realReadingsNumber;
					
					if (CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_DO_MGDL) != "true") 
						followerUserStats.averageGlucose = Math.round(((BgReading.mgdlToMmol((followerUserStats.averageGlucose))) * 10)) / 10;
				}
					
				/**
				 * Variability Screen
				 */
				if (page == BasicUserStats.PAGE_ALL || page == BasicUserStats.PAGE_VARIABILITY)
				{
					var advancedStats:Object = GlucoseFactory.calculateAdvancedStats(cleanReadings, (inRange * 100) / realReadingsNumber);
					var stdDeviation:Number = MathHelper.standardDeviation(cleanReadings);
					followerUserStats.standardDeviation = CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_DO_MGDL) == "true" ? Math.round(stdDeviation * 10) / 10 : Math.round(BgReading.mgdlToMmol(stdDeviation) * 100) / 100;
					followerUserStats.coefficientOfVariation = Math.round(((stdDeviation / advancedStats.glucoseMean) * 100));
					followerUserStats.gvi = advancedStats.GVI != null && !isNaN(advancedStats.GVI) ? advancedStats.GVI : Number.NaN;
					followerUserStats.pgs = advancedStats.PGS != null && !isNaN(advancedStats.PGS) ? advancedStats.PGS : Number.NaN;
					followerUserStats.hourlyChange = advancedStats.meanHourlyChange != null && !isNaN( advancedStats.meanHourlyChange) ? CommonSettings.getCommonSetting(CommonSettings.COMMON_SETTING_DO_MGDL) == "true" ? Math.round(advancedStats.meanHourlyChange * 10) / 10 : Math.round(advancedStats.meanHourlyChange * 100) / 100 : Number.NaN;
					followerUserStats.fluctuation5 = advancedStats.timeInFluctuation != null && !isNaN(advancedStats.timeInFluctuation) ? advancedStats.timeInFluctuation : Number.NaN;
					followerUserStats.fluctuation10 = advancedStats.timeInRapidFluctuation != null && !isNaN(advancedStats.timeInRapidFluctuation) ? advancedStats.timeInRapidFluctuation : Number.NaN;
				}
					
				/**
				 * Treatments Screen
				 */
				if (page == BasicUserStats.PAGE_ALL || page == BasicUserStats.PAGE_TREATMENTS)
				{
					var totalBolus:Number = 0;
					var totalCarbs:Number = 0;
					var totalExercise:Number = 0;
					
					var numberOfTreatments:uint = TreatmentsManager.treatmentsList.length;
					for (i = 0; i < numberOfTreatments; i++) 
					{
						var treatment:Treatment = TreatmentsManager.treatmentsList[i];
						if (treatment != null && treatment.timestamp <= now && treatment.timestamp >= now - TimeSpan.TIME_24_HOURS)
						{
							totalBolus += treatment.insulinAmount;
							totalCarbs += treatment.carbs;
							if (treatment.type == Treatment.TYPE_EXERCISE) 
								totalExercise += treatment.duration;
						}
					}
					
					followerUserStats.bolus = totalBolus;
					followerUserStats.carbs = totalCarbs;
					followerUserStats.exercise = totalExercise;
				}
				
				return followerUserStats;
			}
		}
	}
}