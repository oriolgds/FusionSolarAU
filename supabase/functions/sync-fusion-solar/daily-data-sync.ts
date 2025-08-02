import { FusionSolarAPI } from './fusion-solar-api.ts'

export async function syncDailyData(
  userId: string,
  stationCode: string,
  token: string,
  fusionSolarAPI: FusionSolarAPI,
  supabaseClient: any
): Promise<void> {
  const dailyDataResponse = await fusionSolarAPI.apiCall(
    '/thirdData/getStationRealKpi',
    token,
    { stationCodes: stationCode }
  )

  if (!dailyDataResponse?.success || !dailyDataResponse.data?.[0]) {
    console.warn(`No daily data for station ${stationCode}`)
    return
  }

  const stationData = dailyDataResponse.data[0]
  const dataMap = stationData.dataItemMap || {}

  const { error } = await supabaseClient
    .from('solar_daily_data')
    .upsert({
      user_id: userId,
      station_code: stationCode,
      day_power: parseFloat(dataMap.day_power || '0'),
      month_power: parseFloat(dataMap.month_power || '0'),
      total_power: parseFloat(dataMap.total_power || '0'),
      day_use_energy: parseFloat(dataMap.day_use_energy || '0'),
      day_on_grid_energy: parseFloat(dataMap.day_on_grid_energy || '0'),
      day_income: parseFloat(dataMap.day_income || '0'),
      total_income: parseFloat(dataMap.total_income || '0'),
      health_state: parseInt(dataMap.real_health_state || '3')
    }, { onConflict: 'user_id' })

  if (error) {
    console.error('Error saving daily data:', error)
    throw error
  }

  console.log(`Daily data synced for user ${userId}`)
}